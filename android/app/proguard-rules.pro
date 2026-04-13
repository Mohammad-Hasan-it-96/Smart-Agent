# Please add these rules to your existing keep rules in order to suppress warnings.
# This is generated automatically by the Android Gradle plugin.
-keep class com.google.android.gms.location.** { *; }
-keep interface com.google.android.gms.location.** { *; }
-keep class ru.dgis.sdk.** { *; }
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider

# ── Smart Agent release rules ─────────────────────────────────────────────────

# SQLite / sqflite — reflection is used at runtime
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }
-dontwarn org.sqlite.**

# Firebase — preserve all Firebase classes required at runtime
-keep class com.google.firebase.** { *; }
-keep interface com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Bluetooth thermal printer (blue_thermal_printer)
-keep class com.gzs.learn.serial.** { *; }
-keep class com.woleapp.** { *; }
-keep class com.example.blue_thermal_printer.** { *; }
-dontwarn com.example.blue_thermal_printer.**

# Flutter plugin registrant — never strip
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# AndroidX FileProvider used for PDF sharing
-keep class androidx.core.content.FileProvider
-keep class androidx.core.content.FileProvider$** { *; }

# Kotlin coroutines / serialization used by HTTP layer
-dontwarn kotlinx.coroutines.**
-dontwarn kotlinx.serialization.**
