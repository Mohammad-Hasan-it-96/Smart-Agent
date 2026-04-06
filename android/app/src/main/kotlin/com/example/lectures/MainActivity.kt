package com.example.lectures

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import androidx.core.content.FileProvider
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "smart_agent/whatsapp_share"
    private val FILE_IMPORT_CHANNEL = "smart_agent/file_import"

    private var pendingFileBytes: ByteArray? = null
    private var pendingFileName: String? = null
    private var fileImportEventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // MUST be called before super.onCreate() so the SplashScreen compat library
        // owns the system splash on Android 12+ and hands control to flutter_native_splash.
        // Without this, Android 12 shows its own default white splash FIRST,
        // creating the double-splash effect.
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── File import event channel (stream to Flutter) ──
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "$FILE_IMPORT_CHANNEL/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    fileImportEventSink = events
                    // If a file was received before Flutter was ready, send it now
                    pendingFileBytes?.let { bytes ->
                        events?.success(mapOf(
                            "bytes" to bytes,
                            "fileName" to (pendingFileName ?: "unknown.smartagent")
                        ))
                        pendingFileBytes = null
                        pendingFileName = null
                    }
                }
                override fun onCancel(arguments: Any?) {
                    fileImportEventSink = null
                }
            })

        // ── File import method channel (pull-based fallback) ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_IMPORT_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getInitialFile") {
                    val fileData = readFileFromIntent(intent)
                    if (fileData != null) {
                        result.success(fileData)
                    } else {
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // ── WhatsApp share channel (existing) ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "sharePdfToWhatsApp") {
                    val filePath = call.argument<String>("filePath")
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message") ?: ""

                    if (filePath.isNullOrEmpty() || phone.isNullOrEmpty()) {
                        result.error(
                            "INVALID_ARGS",
                            "filePath or phone is empty",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error(
                                "FILE_NOT_FOUND",
                                "PDF file not found at path: $filePath",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        val uri: Uri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )

                        val pm = packageManager

                        // Try both standard WhatsApp and WhatsApp Business
                        val candidatePackages = listOf(
                            "com.whatsapp",
                            "com.whatsapp.w4b"
                        )

                        var targetPackage: String? = null
                        for (pkg in candidatePackages) {
                            val installed = try {
                                @Suppress("DEPRECATION")
                                pm.getPackageInfo(pkg, 0)
                                true
                            } catch (_: PackageManager.NameNotFoundException) {
                                false
                            }

                            if (installed) {
                                targetPackage = pkg
                                break
                            }
                        }

                        if (targetPackage == null) {
                            result.error(
                                "WHATSAPP_NOT_INSTALLED",
                                "WhatsApp is not installed",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        // Sanitize phone: keep digits only, WhatsApp expects international format without '+'
                        val sanitizedPhone = phone.replace(Regex("[^0-9]"), "")

                        fun buildIntent(includeJid: Boolean): Intent {
                            return Intent(Intent.ACTION_SEND).apply {
                                type = "application/pdf"
                                `package` = targetPackage
                                putExtra(Intent.EXTRA_STREAM, uri)
                                putExtra(Intent.EXTRA_TEXT, message)
                                if (includeJid && sanitizedPhone.isNotEmpty()) {
                                    putExtra("jid", "${sanitizedPhone}@s.whatsapp.net")
                                }
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                clipData = ClipData.newRawUri("order_pdf", uri)
                            }
                        }

                        // Grant URI permission explicitly to WhatsApp package
                        grantUriPermission(
                            targetPackage,
                            uri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION
                        )

                        // Try direct chat first (jid). If WhatsApp rejects it on this device/version,
                        // fall back to opening WhatsApp share UI (still no system chooser).
                        try {
                            startActivity(buildIntent(includeJid = true))
                            result.success(null)
                        } catch (_: ActivityNotFoundException) {
                            startActivity(buildIntent(includeJid = false))
                            result.success(null)
                        }
                    } catch (e: ActivityNotFoundException) {
                        // WhatsApp installed check can still pass on some devices/variants,
                        // but the share activity might not be resolvable.
                        result.error(
                            "WHATSAPP_NOT_AVAILABLE",
                            "WhatsApp share activity not available",
                            null
                        )
                    } catch (e: Exception) {
                        result.error(
                            "WHATSAPP_SHARE_FAILED",
                            e.localizedMessage ?: "Unknown error",
                            null
                        )
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    // ── Handle re-launch with new intent (singleTop) ──
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIncomingFile(intent)
    }

    private fun handleIncomingFile(intent: Intent) {
        val fileData = readFileFromIntent(intent)
        if (fileData != null) {
            val sink = fileImportEventSink
            if (sink != null) {
                sink.success(fileData)
            } else {
                // Flutter not listening yet, store for later
                pendingFileBytes = fileData["bytes"] as? ByteArray
                pendingFileName = fileData["fileName"] as? String
            }
        }
    }

    private fun readFileFromIntent(intent: Intent): Map<String, Any>? {
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
            }
            else -> null
        }

        if (uri == null) return null

        return try {
            // Read all bytes from the content URI
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: return null

            // Try to extract file name
            var fileName = "unknown.smartagent"
            try {
                val cursor = contentResolver.query(uri, null, null, null, null)
                cursor?.use {
                    if (it.moveToFirst()) {
                        val nameIdx = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                        if (nameIdx >= 0) {
                            fileName = it.getString(nameIdx) ?: fileName
                        }
                    }
                }
            } catch (_: Exception) {}

            // Only accept .smartagent files
            if (!fileName.endsWith(".smartagent", ignoreCase = true)) {
                // Check if the raw bytes look like our JSON structure (fallback)
                val preview = String(bytes.take(100).toByteArray(), Charsets.UTF_8)
                if (!preview.contains("\"companies\"") && !preview.contains("\"medicines\"")) {
                    return null
                }
            }

            mapOf(
                "bytes" to bytes,
                "fileName" to fileName
            )
        } catch (_: Exception) {
            null
        }
    }
}