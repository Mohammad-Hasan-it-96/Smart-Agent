package com.example.lectures

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.content.FileProvider
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "smart_agent/whatsapp_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
}