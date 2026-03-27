import 'dart:convert';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../models/update_config.dart';
import 'settings_service.dart';

class UpdateInfo {
  final String version;
  final String? downloadUrl;
  final String? abi;
  final List<String> updateNotes;

  const UpdateInfo(
    this.version,
    this.downloadUrl, {
    this.abi,
    this.updateNotes = const [],
  });

  bool get hasDownloadUrl => downloadUrl != null && downloadUrl!.isNotEmpty;
}

class UpdateService {
  final String updateConfigUrl =
      'https://drive.google.com/uc?export=download&id=1aMv_VNEFff1XzQeiG80s0aEL4r5_c9ao';

  Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    try {
      final response = await http.get(Uri.parse(updateConfigUrl));
      if (response.statusCode != 200) return null;

      var rawJson = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (rawJson.isNotEmpty && rawJson.codeUnitAt(0) == 0xFEFF) {
        rawJson = rawJson.substring(1);
      }
      final data = json.decode(rawJson) as Map<String, dynamic>;
      final config = UpdateConfig.fromJson(data);

      if (config.latestVersion.isEmpty) return null;

      if (config.apiBaseUrl != null && config.apiBaseUrl!.isNotEmpty) {
        await SettingsService.setApiBaseUrl(config.apiBaseUrl!);
      } else {
        await SettingsService.setApiBaseUrl(SettingsService.defaultApiBaseUrl);
      }

      if (!_isNewerVersion(currentVersion, config.latestVersion)) {
        return null;
      }

      final abi = await _detectDeviceAbi();
      String? url;

      if (abi != null) {
        // Prefer exact ABI match from the remote JSON.
        url = config.downloads[abi];
      }

      // Fallback to generic default link from remote JSON.
      url ??= config.downloads['default'];
      url = _normalizeDownloadUrl(url);

      return UpdateInfo(
        config.latestVersion,
        url,
        abi: abi,
        updateNotes: config.updateNotes,
      );
    } catch (_) {
      // Silent failure: if update check fails, we just behave as "no update".
    }

    return null;
  }

  bool _isNewerVersion(String current, String latest) {
    final currentParts = _parseVersion(current);
    final latestParts = _parseVersion(latest);
    final maxLength =
        currentParts.length > latestParts.length ? currentParts.length : latestParts.length;

    for (int i = 0; i < maxLength; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final latestPart = i < latestParts.length ? latestParts[i] : 0;

      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }

    return false;
  }

  List<int> _parseVersion(String value) {
    return value
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList();
  }

  String? _normalizeDownloadUrl(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      return trimmed;
    }

    // Keep URL handling provider-agnostic (MEGA, direct CDN, etc.).
    return 'https://$trimmed';
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

      // Prefer 64-bit if available.
      for (final abi in abis) {
        final lower = abi.toLowerCase();
        if (lower.contains('arm64')) {
          return 'arm64-v8a';
        }
      }

      // Fallback to 32-bit ARM.
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
