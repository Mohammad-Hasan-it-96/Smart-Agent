import 'dart:convert';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

class UpdateInfo {
  final String version;
  final String? downloadUrl;
  final String? abi;

  const UpdateInfo(this.version, this.downloadUrl, {this.abi});

  bool get hasDownloadUrl => downloadUrl != null && downloadUrl!.isNotEmpty;
}

class UpdateService {
  final String versionJsonUrl =
      "https://drive.google.com/uc?export=download&id=1aMv_VNEFff1XzQeiG80s0aEL4r5_c9ao";

  Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    try {
      final response = await http.get(Uri.parse(versionJsonUrl));
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;

      final latest = data["latest_version"] as String?;
      if (latest == null) return null;

      if (!_isNewerVersion(currentVersion, latest)) {
        return null;
      }

      // Backwards compatibility: support old flat 'download_url' field
      if (data.containsKey("download_url")) {
        final url = data["download_url"] as String?;
        if (url != null && url.isNotEmpty) {
          return UpdateInfo(latest, url);
        }
      }

      // New format with per-ABI downloads
      final downloads = data["downloads"];
      if (downloads is Map<String, dynamic>) {
        final abi = await _detectDeviceAbi();
        String? url;

        if (abi != null) {
          url = downloads[abi] as String?;
        }

        // If URL is null, caller/dialog will show a support message
        return UpdateInfo(latest, url, abi: abi);
      }
    } catch (e) {
      // Silent failure: if update check fails, we just behave as "no update"
      // You can add logging here if needed.
    }

    return null;
  }

  bool _isNewerVersion(String current, String latest) {
    final c = current.split('.').map(int.parse).toList();
    final l = latest.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  /// Detect the preferred ABI for this device.
  ///
  /// Returns values like 'arm64-v8a' or 'armeabi-v7a', or null if unknown.
  Future<String?> _detectDeviceAbi() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final abis = androidInfo.supportedAbis;

      if (abis.isEmpty) return null;

      // Prefer 64-bit if available
      for (final abi in abis) {
        final lower = abi.toLowerCase();
        if (lower.contains('arm64')) {
          return 'arm64-v8a';
        }
      }

      // Fallback to 32-bit arm
      for (final abi in abis) {
        final lower = abi.toLowerCase();
        if (lower.contains('armeabi-v7a') || lower.contains('armeabi')) {
          return 'armeabi-v7a';
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
