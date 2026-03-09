import 'dart:convert';

import 'package:http/http.dart' as http;

class NotificationApiService {
  static const String _createDeviceApiUrl =
      'https://harrypotter.foodsalebot.com/api/create_device';
  static const String _updateMyDataApiUrl =
      'https://harrypotter.foodsalebot.com/api/update_my_data';

  Future<bool> sendCreateDeviceWithToken({
    required String appName,
    required String deviceId,
    required String fullName,
    required String phone,
    required String fcmToken,
  }) async {
    final response = await http
        .post(
          Uri.parse(_createDeviceApiUrl),
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
          Uri.parse(_updateMyDataApiUrl),
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

