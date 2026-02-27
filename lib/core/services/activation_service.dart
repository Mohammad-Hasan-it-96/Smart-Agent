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
  static const String _subscriptionRequestSentKey = 'subscription_request_sent';
  static const String _activationRequestedKey = 'activation_requested';
  static const String _selectedPlanKey = 'selected_plan';
  static const String _requestTimestampKey = 'request_timestamp';
  static const String _expiresAtKey = 'expires_at';
  static const String _lastTrustedTimeKey = 'last_trusted_time';
  static const String _timeOffsetKey = 'time_offset_seconds';
  static const String _timeTamperedKey = 'time_tampered';
  static const String _lastOnlineSyncKey = 'last_online_sync';
  static const String _offlineLimitExceededKey = 'offline_limit_exceeded';
  static const String _agentNameKey = 'agent_full_name';
  static const String _agentPhoneKey = 'agent_phone';
  static const String _expiresAtFileName = 'activation_expires_at.txt';
  static const String _apiUrl =
      'https://harrypotter.foodsalebot.com/api/create_device';
  static const String _checkDeviceApiUrl =
      'https://harrypotter.foodsalebot.com/api/check_device';
  static const String _updateMyDataApiUrl =
      'https://harrypotter.foodsalebot.com/api/update_my_data';
  static const int _timeTamperThresholdMinutes = 5;
  static const int _offlineLimitHours = 72;

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
        final expiresAt = responseData['expires_at'] as String?;
        final serverTime = responseData['server_time'] as String?;

        // Update trusted time from server
        if (serverTime != null && serverTime.isNotEmpty) {
          await _updateTrustedTime(serverTime);
        }

        // Update last online sync timestamp (successful connection)
        await _updateLastOnlineSync();

        // Convert to bool (1 = true, 0 = false)
        final verified = isVerified == 1 || isVerified == true;

        // Save activation_verified status
        await _saveActivationVerified(verified);

        // If verified, save expires_at and disable trial mode
        if (verified && expiresAt != null && expiresAt.isNotEmpty) {
          await _saveExpiresAt(expiresAt);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_trialActiveKey, false);
          await prefs.setBool(_trialEnabledKey, false);
        } else if (verified) {
          // Verified but no expires_at - legacy activation (no expiration)
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

  // Save expires_at to both SharedPreferences and local file
  Future<void> _saveExpiresAt(String expiresAt) async {
    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_expiresAtKey, expiresAt);

    // Save to local file for redundancy/security
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_expiresAtFileName');
      await file.writeAsString(expiresAt);
    } catch (e) {
      // If file write fails, continue with SharedPreferences only
      // This is not critical as SharedPreferences is the primary storage
    }
  }

  // Update trusted time from server
  // Calculates offset between server time and device time
  Future<void> _updateTrustedTime(String serverTimeString) async {
    try {
      final serverTime = DateTime.parse(serverTimeString).toUtc();
      final deviceTime = DateTime.now().toUtc();
      
      // Calculate offset (server time - device time) in seconds
      final offsetSeconds = serverTime.difference(deviceTime).inSeconds;
      
      // Calculate trusted time (server time)
      final trustedTime = serverTime;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastTrustedTimeKey, trustedTime.toIso8601String());
      await prefs.setInt(_timeOffsetKey, offsetSeconds);
      await prefs.setBool(_timeTamperedKey, false); // Reset tamper flag on successful sync
    } catch (e) {
      // If parsing fails, don't update trusted time
    }
  }

  // Get last trusted time
  Future<DateTime?> getLastTrustedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final trustedTimeString = prefs.getString(_lastTrustedTimeKey);
    if (trustedTimeString == null || trustedTimeString.isEmpty) {
      return null;
    }
    
    try {
      return DateTime.parse(trustedTimeString).toUtc();
    } catch (e) {
      return null;
    }
  }

  // Get time offset (server time - device time) in seconds
  Future<int> getTimeOffset() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_timeOffsetKey) ?? 0;
  }

  // Check for time tampering
  // Returns true if time tampering is detected
  Future<bool> checkTimeTampering() async {
    final lastTrustedTime = await getLastTrustedTime();
    if (lastTrustedTime == null) {
      // No trusted time yet - first run, not tampering
      return false;
    }

    final currentDeviceTime = DateTime.now().toUtc();
    final timeOffset = await getTimeOffset();
    
    // Calculate adjusted device time (accounting for known offset)
    final adjustedDeviceTime = currentDeviceTime.add(Duration(seconds: timeOffset));
    
    // Check if device time went backwards significantly
    // If adjusted device time is less than last trusted time by more than threshold, it's tampering
    final timeDifference = lastTrustedTime.difference(adjustedDeviceTime);
    
    if (timeDifference.inMinutes > _timeTamperThresholdMinutes) {
      // Time tampering detected - device time went backwards
      await _handleTimeTampering();
      return true;
    }

    // No tampering detected
    return false;
  }

  // Handle time tampering detection
  Future<void> _handleTimeTampering() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_timeTamperedKey, true);
    
    // Disable paid features by clearing activation
    await _saveActivationVerified(false);
  }

  // Check if time tampering was detected
  Future<bool> isTimeTampered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_timeTamperedKey) ?? false;
  }

  // Clear time tampering flag (after reconnecting to server)
  Future<void> clearTimeTamperingFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_timeTamperedKey, false);
  }

  // Update last online sync timestamp
  Future<void> _updateLastOnlineSync() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc().toIso8601String();
    await prefs.setString(_lastOnlineSyncKey, now);
    // Clear offline limit exceeded flag on successful sync
    await prefs.setBool(_offlineLimitExceededKey, false);
  }

  // Get last online sync timestamp
  Future<DateTime?> getLastOnlineSync() async {
    final prefs = await SharedPreferences.getInstance();
    final syncString = prefs.getString(_lastOnlineSyncKey);
    if (syncString == null || syncString.isEmpty) {
      return null;
    }
    
    try {
      return DateTime.parse(syncString).toUtc();
    } catch (e) {
      return null;
    }
  }

  // Check if offline limit (72 hours) has been exceeded
  Future<bool> isOfflineLimitExceeded() async {
    final lastSync = await getLastOnlineSync();
    if (lastSync == null) {
      // No sync recorded yet - allow operation (first run)
      return false;
    }

    final now = DateTime.now().toUtc();
    final timeSinceLastSync = now.difference(lastSync);
    
    // Check if more than 72 hours have passed
    if (timeSinceLastSync.inHours > _offlineLimitHours) {
      // Mark as exceeded
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_offlineLimitExceededKey, true);
      return true;
    }

    // Check if flag was previously set (in case time was adjusted)
    final prefs = await SharedPreferences.getInstance();
    final previouslyExceeded = prefs.getBool(_offlineLimitExceededKey) ?? false;
    
    // If time is now within limit, clear the flag
    if (previouslyExceeded && timeSinceLastSync.inHours <= _offlineLimitHours) {
      await prefs.setBool(_offlineLimitExceededKey, false);
      return false;
    }

    return previouslyExceeded;
  }

  // Check if offline limit is currently exceeded (cached check)
  Future<bool> hasOfflineLimitExceeded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_offlineLimitExceededKey) ?? false;
  }

  // Get expires_at from SharedPreferences or local file
  Future<String?> getExpiresAt() async {
    // Try SharedPreferences first
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = prefs.getString(_expiresAtKey);
    if (expiresAt != null && expiresAt.isNotEmpty) {
      return expiresAt;
    }

    // Fallback to local file
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_expiresAtFileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          // Also save to SharedPreferences for faster access next time
          await prefs.setString(_expiresAtKey, content);
          return content;
        }
      }
    } catch (e) {
      // File read failed, return null
    }

    return null;
  }

  // Check device status from server and update expires_at
  // This should be called on app startup to sync expiration date
  Future<bool> checkDeviceStatus() async {
    try {
      final deviceId = await getDeviceId();
      final agentName = await getAgentName();
      final agentPhone = await getAgentPhone();

      if (agentName.isEmpty || agentPhone.isEmpty) {
        return false;
      }

      final requestBody = {
        'device_id': deviceId,
        'app_name': 'SmartAgent',
      };

      final response = await http
          .post(
        Uri.parse(_checkDeviceApiUrl),
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
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final isVerified = responseData['is_verified'];
        final expiresAt = responseData['expires_at'] as String?;
        final serverTime = responseData['server_time'] as String?;

        // Update trusted time from server
        if (serverTime != null && serverTime.isNotEmpty) {
          await _updateTrustedTime(serverTime);
        }

        // Update last online sync timestamp (successful connection)
        await _updateLastOnlineSync();

        // Convert to bool (1 = true, 0 = false)
        final verified = isVerified == 1 || isVerified == true;

        // Update activation status
        await _saveActivationVerified(verified);

        // Update expires_at if provided
        if (expiresAt != null && expiresAt.isNotEmpty) {
          await _saveExpiresAt(expiresAt);
        }

        return verified;
      } else {
        return false;
      }
    } catch (e) {
      // Re-throw the exception to let caller know that connection failed
      rethrow;
    }
  }

  // Update user data on server
  Future<bool> updateMyData(String fullName, String phone) async {
    try {
      final deviceId = await getDeviceId();

      final requestBody = {
        'device_id': deviceId,
        'app_name': 'SmartAgent',
        'full_name': fullName,
        'phone': phone,
      };

      final response = await http
          .post(
        Uri.parse(_updateMyDataApiUrl),
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
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final success = responseData['success'] == true || responseData['success'] == 1;
        return success;
      } else {
        return false;
      }
    } catch (e) {
      // Re-throw the exception to let caller know that connection failed
      rethrow;
    }
  }

  // Check if license has expired
  // IMPORTANT: This uses expires_at from server, not just DateTime.now()
  Future<bool> isLicenseExpired() async {
    final expiresAt = await getExpiresAt();
    if (expiresAt == null || expiresAt.isEmpty) {
      // No expiration date means legacy activation (no expiration)
      return false;
    }

    try {
      // Parse ISO 8601 UTC string
      final expirationDate = DateTime.parse(expiresAt).toUtc();
      final now = DateTime.now().toUtc();
      
      // License is expired if current time >= expiration time
      return now.isAfter(expirationDate) || now.isAtSameMomentAs(expirationDate);
    } catch (e) {
      // If parsing fails, assume not expired (fail-safe)
      return false;
    }
  }

  // Check if device is activated from SharedPreferences
  // IMPORTANT: This checks expires_at from server, not just DateTime.now()
  // Always compares current time with server-provided expires_at
  // Also checks for time tampering
  Future<bool> isActivated() async {
    // First check for time tampering
    final tampered = await isTimeTampered();
    if (tampered) {
      return false; // Time tampered - disable paid features
    }

    final prefs = await SharedPreferences.getInstance();
    // Check new key first, fallback to old key
    final verified = prefs.getBool(_activationVerifiedKey);
    final isVerified = verified ?? prefs.getBool(_activationKey) ?? false;

    if (!isVerified) {
      return false;
    }

    // If verified, check if license has expired using server-provided expires_at
    // This is the primary validation - we don't rely on DateTime.now() alone
    final expired = await isLicenseExpired();
    if (expired) {
      // License expired - clear activation status
      await _saveActivationVerified(false);
      return false;
    }

    return true;
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

  // Send subscription activation request to backend API
  // This is called when user selects a plan and contact method
  Future<bool> sendSubscriptionActivationRequest({
    required String deviceId,
    required String agentName,
    required String agentPhone,
    required String planId, // 'half_year' or 'yearly'
    required String contactMethod, // 'email' or 'telegram'
  }) async {
    try {
      // Map plan ID to API format
      String requestedPlan;
      switch (planId) {
        case 'half_year':
          requestedPlan = '6_months';
          break;
        case 'yearly':
          requestedPlan = '12_months';
          break;
        default:
          requestedPlan = '6_months'; // Default fallback
      }

      // Prepare request body
      final requestBody = {
        'app_name': 'SmartAgent',
        'device_id': deviceId,
        'full_name': agentName,
        'phone': agentPhone,
        'requested_plan': requestedPlan,
        'contact_method': contactMethod,
        'status': 'pending',
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
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse response for potential activation data
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final isVerified = responseData['is_verified'];
        final expiresAt = responseData['expires_at'] as String?;
        final serverTime = responseData['server_time'] as String?;

        // Update trusted time from server
        if (serverTime != null && serverTime.isNotEmpty) {
          await _updateTrustedTime(serverTime);
        }

        // Mark that subscription request was sent
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_subscriptionRequestSentKey, true);
        
        // Save activation request state
        await _saveActivationRequestState(planId);

        // If activation was successful, save expires_at
        final verified = isVerified == 1 || isVerified == true;
        if (verified && expiresAt != null && expiresAt.isNotEmpty) {
          await _saveExpiresAt(expiresAt);
          await _saveActivationVerified(true);
        }
        
        return true;
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      // Don't throw - let caller handle gracefully
      // The request will be retried later if needed
      return false;
    }
  }

  // Save activation request state locally
  Future<void> _saveActivationRequestState(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activationRequestedKey, true);
    await prefs.setString(_selectedPlanKey, planId);
    await prefs.setString(_requestTimestampKey, DateTime.now().toIso8601String());
  }

  // Public method to save activation request state (called before API call)
  Future<void> saveActivationRequestState(String planId) async {
    await _saveActivationRequestState(planId);
  }

  // Check if activation request was already sent
  Future<bool> hasActivationRequestBeenSent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_activationRequestedKey) ?? false;
  }

  // Get selected plan from saved state
  Future<String?> getSelectedPlan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedPlanKey);
  }

  // Get request timestamp
  Future<String?> getRequestTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_requestTimestampKey);
  }

  // Check if subscription activation request was sent (legacy method)
  Future<bool> hasSubscriptionRequestBeenSent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_subscriptionRequestSentKey) ?? false;
  }
}
