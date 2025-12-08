import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../exceptions/trial_expired_exception.dart';

enum ActivationState {
  checking,
  notActivated,
  activated,
}

class ActivationService {
  static const String _activationKey = 'is_activated';
  static const String _activationVerifiedKey = 'activation_verified';
  static const String _activationCalledKey = 'activation_api_called';
  static const String _agentNameKey = 'agent_full_name';
  static const String _agentPhoneKey = 'agent_phone';
  static const String _apiUrl =
      'https://harrypotter.africaxbet.com/api/create_device';

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

  // Send activation request to backend API
  // Returns: true if is_verified = 1, false if is_verified = 0, throws on error
  Future<bool> sendActivationRequest(
      String fullName, String phone, String deviceId) async {
    try {
      // Prepare request body
      final requestBody = {
        'app_name': 'SmartAgent',
        'device_id': deviceId,
        'full_name': fullName,
        'phone': phone,
      };

      final response = await http
          .post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (response.statusCode == 200) {
        // Parse response
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final isVerified = responseData['is_verified'];

        // Convert to bool (1 = true, 0 = false)
        final verified = isVerified == 1 || isVerified == true;

        // Save activation_verified status
        await _saveActivationVerified(verified);

        // If verified, disable trial mode
        if (verified) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_trialActiveKey, false);
          await prefs.setBool(_trialEnabledKey, false);
        }

        // Mark that API has been called
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_activationCalledKey, true);

        return verified;
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      // Re-throw to let caller handle the error
      throw Exception('فشل الاتصال – حاول لاحقاً: ${e.toString()}');
    }
  }

  // Check if activation API has been called
  Future<bool> hasActivationBeenCalled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_activationCalledKey) ?? false;
  }

  // Save activation verified status
  Future<void> _saveActivationVerified(bool verified) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activationVerifiedKey, verified);
    // Also save to old key for backward compatibility
    await prefs.setBool(_activationKey, verified);
  }

  // Get activation verified status
  Future<bool?> getActivationVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_activationVerifiedKey);
  }

  // Save activation status to SharedPreferences
  Future<void> saveActivationStatus(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activationKey, value);
  }

  // Check if device is activated from SharedPreferences
  Future<bool> isActivated() async {
    final prefs = await SharedPreferences.getInstance();
    // Check new key first, fallback to old key
    final verified = prefs.getBool(_activationVerifiedKey);
    if (verified != null) {
      return verified;
    }
    return prefs.getBool(_activationKey) ?? false;
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

  // ============================================
  // TRIAL MODE METHODS
  // ============================================

  static const String _trialEnabledKey = 'trial_enabled';
  static const String _trialActiveKey = 'trial_active';
  static const String _trialPharmaciesLimitKey = 'trial_limit_pharmacies';
  static const String _trialCompaniesLimitKey = 'trial_limit_companies';
  static const String _trialMedicinesLimitKey = 'trial_limit_medicines';
  static const String _trialUsedOnceFileName = 'trial_used_once.flag';

  // Initialize trial limits (called on first trial activation)
  Future<void> _initializeTrialLimits() async {
    final prefs = await SharedPreferences.getInstance();
    // Set default limits if not already set
    if (prefs.getInt(_trialPharmaciesLimitKey) == null) {
      await prefs.setInt(_trialPharmaciesLimitKey, 1);
    }
    if (prefs.getInt(_trialCompaniesLimitKey) == null) {
      await prefs.setInt(_trialCompaniesLimitKey, 2);
    }
    if (prefs.getInt(_trialMedicinesLimitKey) == null) {
      await prefs.setInt(_trialMedicinesLimitKey, 10);
    }
  }

  // Check if trial was used once (tamper-proof)
  Future<bool> hasTrialBeenUsedOnce() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_trialUsedOnceFileName');
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  // Mark trial as used once (tamper-proof)
  Future<void> markTrialAsUsedOnce() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_trialUsedOnceFileName');
      await file.writeAsString('trial_used');
    } catch (e) {
      // Ignore errors
    }
  }

  // Enable trial mode
  Future<void> enableTrialMode() async {
    // Check if trial was already used once
    final usedOnce = await hasTrialBeenUsedOnce();
    if (usedOnce) {
      throw Exception('تم استخدام النسخة التجريبية مسبقاً');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trialEnabledKey, true);
    await prefs.setBool(_trialActiveKey, true);
    await _initializeTrialLimits();
    await markTrialAsUsedOnce();
  }

  // Disable trial mode (when expired)
  Future<void> disableTrialMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trialEnabledKey, false);
    await prefs.setBool(_trialActiveKey, false);
  }

  // Check if trial mode is enabled
  Future<bool> isTrialEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_trialEnabledKey) ?? false;
  }

  // Check if trial mode is active
  Future<bool> isTrialActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_trialActiveKey) ?? false;
  }

  // Get trial pharmacies limit
  Future<int> getTrialPharmaciesLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_trialPharmaciesLimitKey) ?? 1;
  }

  // Get trial companies limit
  Future<int> getTrialCompaniesLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_trialCompaniesLimitKey) ?? 2;
  }

  // Get trial medicines limit
  Future<int> getTrialMedicinesLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_trialMedicinesLimitKey) ?? 10;
  }

  // Check if currently in trial mode
  Future<bool> isTrialMode() async {
    final verified = await getActivationVerified();
    if (verified == true) {
      return false; // Activated, not in trial
    }
    final trialActive = await isTrialActive();
    return trialActive;
  }

  // Check trial limit for pharmacies
  Future<void> checkTrialLimitPharmacies() async {
    if (!await isTrialMode()) {
      return; // Not in trial mode, no limit
    }

    final db = await DatabaseHelper.instance.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM pharmacies');
    final count = result.first['count'] as int;
    final limit = await getTrialPharmaciesLimit();

    if (count >= limit) {
      await disableTrialMode();
      throw TrialExpiredException('pharmacies');
    }
  }

  // Check trial limit for companies
  Future<void> checkTrialLimitCompanies() async {
    if (!await isTrialMode()) {
      return; // Not in trial mode, no limit
    }

    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM companies');
    final count = result.first['count'] as int;
    final limit = await getTrialCompaniesLimit();

    if (count >= limit) {
      await disableTrialMode();
      throw TrialExpiredException('companies');
    }
  }

  // Check trial limit for medicines
  Future<void> checkTrialLimitMedicines() async {
    if (!await isTrialMode()) {
      return; // Not in trial mode, no limit
    }

    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM medicines');
    final count = result.first['count'] as int;
    final limit = await getTrialMedicinesLimit();

    if (count >= limit) {
      await disableTrialMode();
      throw TrialExpiredException('medicines');
    }
  }

  // Check if trial has expired (any limit reached)
  Future<bool> hasTrialExpired() async {
    if (!await isTrialMode()) {
      return false; // Not in trial mode, so not expired
    }

    try {
      await checkTrialLimitPharmacies();
      await checkTrialLimitCompanies();
      await checkTrialLimitMedicines();
      return false;
    } catch (e) {
      if (e is TrialExpiredException) {
        return true;
      }
      return false;
    }
  }
}
