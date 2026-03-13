import 'dart:convert';

import 'package:http/http.dart' as http;

import 'settings_service.dart';

class NotificationApiService {
  static const String _createDeviceEndpoint = 'create_device';
  static const String _updateMyDataEndpoint = 'update_my_data';

  Future<bool> sendCreateDeviceWithToken({
    required String appName,
    required String deviceId,
    required String fullName,
    required String phone,
    required String fcmToken,
  }) async {
    final response = await http
        .post(
          await SettingsService.buildApiUri(_createDeviceEndpoint),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'app_name': appName,
            'device_id': deviceId,
            'full_name': fullName,
            'phone': phone,
            'fcm_token': fcmToken,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['success'] == true || data['success'] == 1;
  }

  Future<bool> updateFcmToken({
    required String deviceId,
    required String fcmToken,
  }) async {
    final response = await http
        .post(
          await SettingsService.buildApiUri(_updateMyDataEndpoint),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'device_id': deviceId,
            'fcm_token': fcmToken,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['success'] == true || data['success'] == 1;
  }
}

