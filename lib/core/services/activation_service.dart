import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum ActivationState {
  checking,
  notActivated,
  activated,
}

class ActivationService {
  static const String _activationKey = 'is_activated';
  static const String _dummyApiUrl = 'https://api.example.com/activate';

  // Get device ID using device_info_plus or fallback
  Future<String> getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown';
      } else {
        // Fallback for other platforms
        return 'unknown_device';
      }
    } catch (e) {
      // Fallback if device_info_plus fails
      return 'fallback_device_id';
    }
  }

  // Check online activation via POST request
  Future<bool> checkOnlineActivation(String deviceId) async {
    try {
      final response = await http.post(
        Uri.parse(_dummyApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'device_id': deviceId,
        }),
      );

      // Return true if activation is successful (status 200)
      return response.statusCode == 200;
    } catch (e) {
      // Return false on error
      return false;
    }
  }

  // Save activation status to SharedPreferences
  Future<void> saveActivationStatus(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activationKey, value);
  }

  // Check if device is activated from SharedPreferences
  Future<bool> isActivated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_activationKey) ?? false;
  }
}
