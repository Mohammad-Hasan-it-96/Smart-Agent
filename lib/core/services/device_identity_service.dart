import 'dart:convert';
import 'dart:io';
import 'package:android_id/android_id.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../constants/app_constants.dart';

/// Responsible for generating a stable, app-unique device identifier.
///
/// The generated ID is used by [ActivationService] when registering or
/// checking a device with the backend API.
///
/// Platform behaviour:
///   Android – SHA-256(ANDROID_ID + [AppConstants.apiSalt]).
///             Survives app reinstalls on the same signing key.
///   iOS     – `identifierForVendor` (resets on full app removal).
///   Other   – constant `'unknown_device'` fallback.
class DeviceIdentityService {
  /// Returns the stable device identifier for the current platform.
  ///
  /// Never throws; returns `'fallback_device_id'` on any error so that
  /// callers do not need error handling for this specific step.
  Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        const androidIdPlugin = AndroidId();
        final rawId = await androidIdPlugin.getId() ?? '';
        if (rawId.isEmpty) return 'fallback_device_id';
        final bytes = utf8.encode('$rawId${AppConstants.apiSalt}');
        final digest = sha256.convert(bytes);
        return digest.toString();
      } else if (Platform.isIOS) {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown';
      } else {
        return 'unknown_device';
      }
    } catch (_) {
      return 'fallback_device_id';
    }
  }
}

