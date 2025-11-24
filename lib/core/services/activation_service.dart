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
  static const String _agentNameKey = 'agent_full_name';
  static const String _agentPhoneKey = 'agent_phone';
  static const String _agentDataSentKey = 'agent_data_sent';
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
  // TEMPORARY: Always returns true for development/testing
  // TODO: Re-enable API call when ready for production
  Future<bool> checkOnlineActivation(String deviceId) async {
    // Temporarily bypass activation - always return true
    return true;

    // COMMENTED OUT: API call disabled temporarily
    // TODO: Uncomment when API integration is ready
    /*
    try {
      final prefs = await SharedPreferences.getInstance();
      final agentDataSent = prefs.getBool(_agentDataSentKey) ?? false;
      
      // Prepare request body
      Map<String, dynamic> requestBody = {
        'device_id': deviceId,
      };
      
      // Include agent data ONLY on first activation (first time only)
      if (!agentDataSent) {
        final agentName = await getAgentName();
        final agentPhone = await getAgentPhone();
        
        if (agentName.isNotEmpty && agentPhone.isNotEmpty) {
          requestBody['full_name'] = agentName;
          requestBody['phone'] = agentPhone;
        }
      }
      
      final response = await http.post(
        Uri.parse(_dummyApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      // If activation is successful and agent data was sent for the first time, mark it
      if (response.statusCode == 200 && !agentDataSent) {
        await prefs.setBool(_agentDataSentKey, true);
      }

      // Return true if activation is successful (status 200)
      return response.statusCode == 200;
    } catch (e) {
      // Return false on error
      return false;
    }
    */
  }

  // Save activation status to SharedPreferences
  Future<void> saveActivationStatus(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activationKey, value);
  }

  // Check if device is activated from SharedPreferences
  // TEMPORARY: Always returns true for development/testing
  // TODO: Re-enable SharedPreferences check when ready for production
  Future<bool> isActivated() async {
    // Temporarily bypass activation check - always return true
    return true;

    // COMMENTED OUT: SharedPreferences check disabled temporarily
    // TODO: Uncomment when activation is required
    /*
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_activationKey) ?? false;
    */
  }

  // Agent data helper functions
  Future<String> getAgentName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_agentNameKey) ?? '';
  }

  Future<String> getAgentPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_agentPhoneKey) ?? '';
  }

  Future<void> saveAgentName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_agentNameKey, name);
  }

  Future<void> saveAgentPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_agentPhoneKey, phone);
  }

  // Check if agent data exists
  Future<bool> hasAgentData() async {
    final name = await getAgentName();
    final phone = await getAgentPhone();
    return name.isNotEmpty && phone.isNotEmpty;
  }
}
