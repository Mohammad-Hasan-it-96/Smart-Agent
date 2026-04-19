import 'activation_local_storage.dart';
import 'device_api_repository.dart';
import 'device_identity_service.dart';
import 'offline_limit_guard.dart';
import 'time_tamper_guard.dart';
import 'trial_mode_service.dart';

enum ActivationState {
  checking,
  notActivated,
  activated,
}

class ActivationService {
  // Delegate persistence to ActivationLocalStorage.
  final ActivationLocalStorage _localStorage;

  // Delegate device-ID generation to DeviceIdentityService.
  final DeviceIdentityService _deviceIdentity;

  // Delegate remote API calls to DeviceApiRepository.
  final DeviceApiRepository _api;

  // Delegate time-tamper detection arithmetic to TimeTamperGuard.
  final TimeTamperGuard _tamperGuard;

  // Delegate offline-limit evaluation arithmetic to OfflineLimitGuard.
  final OfflineLimitGuard _offlineGuard;

  // Delegate trial-mode business logic to TrialModeService.
  final TrialModeService _trialService;

  ActivationService({
    required ActivationLocalStorage localStorage,
    required DeviceIdentityService deviceIdentity,
    required DeviceApiRepository api,
    required TimeTamperGuard tamperGuard,
    required OfflineLimitGuard offlineGuard,
    required TrialModeService trialService,
  })  : _localStorage = localStorage,
        _deviceIdentity = deviceIdentity,
        _api = api,
        _tamperGuard = tamperGuard,
        _offlineGuard = offlineGuard,
        _trialService = trialService;

  // ── Device identity ───────────────────────────────────────────────────
  // Delegates to DeviceIdentityService — see that class for platform details.
  Future<String> getDeviceId() => _deviceIdentity.getDeviceId();

  // ── Activation requests ───────────────────────────────────────────────

  // Send activation request to backend API.
  // Returns: true if is_verified = 1, false if 0, throws on error.
  Future<bool> sendActivationRequest(
      String fullName, String phone, String deviceId) async {
    try {
      final data = await _api.createDevice(
        deviceId: deviceId,
        fullName: fullName,
        phone: phone,
      );

      final serverTime = data['server_time'] as String?;
      if (serverTime != null && serverTime.isNotEmpty) {
        await _localStorage.saveTrustedTimeAndOffset(serverTime);
      }
      await _localStorage.updateLastOnlineSync();

      final isVerified = data['is_verified'];
      final verified = isVerified == 1 || isVerified == true;
      await _localStorage.saveActivationVerified(verified);

      final expiresAt = data['expires_at'] as String?;
      if (verified && expiresAt != null && expiresAt.isNotEmpty) {
        await _localStorage.saveExpiresAt(expiresAt);
        await _trialService.disableTrialMode();
      } else if (verified) {
        // Verified but no expires_at – legacy activation (no expiration).
        await _trialService.disableTrialMode();
      }

      final plan = data['plan'] as String?;
      if (plan != null && plan.isNotEmpty) {
        await _localStorage.saveSelectedPlan(plan);
      }
      await _localStorage.setActivationCalled();

      // Save user_id from API response if available
      final userId = data['user_id'];
      if (userId != null) {
        await _localStorage.saveUserId(userId.toString());
      }

      return verified;
    } catch (e) {
      throw Exception('فشل الاتصال – حاول لاحقاً: ${e.toString()}');
    }
  }

  // Check if activation API has been called.
  Future<bool> hasActivationBeenCalled() =>
      _localStorage.hasActivationBeenCalled();

  // Get activation verified status.
  Future<bool?> getActivationVerified() =>
      _localStorage.getActivationVerified();

  // Save activation status to SharedPreferences.
  Future<void> saveActivationStatus(bool value) =>
      _localStorage.saveActivationStatus(value);

  // ── Trusted time & time-tamper guard ──────────────────────────────────

  // Get last trusted time.
  Future<DateTime?> getLastTrustedTime() => _localStorage.getLastTrustedTime();

  // Get time offset (server time − device time) in seconds.
  Future<int> getTimeOffset() => _localStorage.getTimeOffset();

  // Check for time tampering. Returns true if detected.
  Future<bool> checkTimeTampering() async {
    final lastTrustedTime = await getLastTrustedTime();
    if (lastTrustedTime == null) {
      // No trusted time yet – first run, not tampering.
      return false;
    }

    final tampered = _tamperGuard.isTampered(
      lastTrustedTime: lastTrustedTime,
      deviceTime: DateTime.now().toUtc(),
      timeOffsetSeconds: await getTimeOffset(),
    );

    if (tampered) {
      await _handleTimeTampering();
      return true;
    }
    return false;
  }

  Future<void> _handleTimeTampering() async {
    await _localStorage.setTimeTampered(true);
    await _localStorage.saveActivationVerified(false);
  }

  // Check if time tampering was detected.
  Future<bool> isTimeTampered() => _localStorage.isTimeTampered();

  // Clear time tampering flag (after reconnecting to server).
  Future<void> clearTimeTamperingFlag() =>
      _localStorage.clearTimeTamperingFlag();

  // ── Online sync & offline limit ───────────────────────────────────────

  // Get last online sync timestamp.
  Future<DateTime?> getLastOnlineSync() => _localStorage.getLastOnlineSync();

  // Check if offline limit (72 hours) has been exceeded.
  Future<bool> isOfflineLimitExceeded() async {
    final lastSync = await getLastOnlineSync();
    if (lastSync == null) {
      // No sync recorded yet – allow (first run).
      return false;
    }

    final timeSinceLastSync = DateTime.now().toUtc().difference(lastSync);

    if (_offlineGuard.hasExceeded(timeSinceLastSync)) {
      await _localStorage.setOfflineLimitExceeded(true);
      return true;
    }

    final previouslyExceeded = await _localStorage.hasOfflineLimitExceeded();

    if (_offlineGuard.shouldClearExceededFlag(timeSinceLastSync, previouslyExceeded)) {
      // Was exceeded but time came back within the window – clear the flag.
      await _localStorage.setOfflineLimitExceeded(false);
      return false;
    }

    return previouslyExceeded;
  }

  // Check if offline limit is currently exceeded (cached read).
  Future<bool> hasOfflineLimitExceeded() =>
      _localStorage.hasOfflineLimitExceeded();

  // ── Expiry ────────────────────────────────────────────────────────────

  // Get expires_at from SharedPreferences or local file.
  Future<String?> getExpiresAt() => _localStorage.getExpiresAt();

  // ── Device-status API ─────────────────────────────────────────────────

  // Check device status from server and update local state.
  // Should be called on app startup to sync expiration date.
  Future<bool> checkDeviceStatus() async {
    try {
      final deviceId = await getDeviceId();
      final agentName = await getAgentName();
      final agentPhone = await getAgentPhone();

      if (agentName.isEmpty || agentPhone.isEmpty) return false;

      final data = await _api.checkDevice(deviceId: deviceId);
      if (data == null) return false; // non-200 → treat as not verified

      final serverTime = data['server_time'] as String?;
      if (serverTime != null && serverTime.isNotEmpty) {
        await _localStorage.saveTrustedTimeAndOffset(serverTime);
      }
      await _localStorage.updateLastOnlineSync();

      final isVerified = data['is_verified'];
      final verified = isVerified == 1 || isVerified == true;
      await _localStorage.saveActivationVerified(verified);

      final expiresAt = data['expires_at'] as String?;
      if (expiresAt != null && expiresAt.isNotEmpty) {
        await _localStorage.saveExpiresAt(expiresAt);
      }

      final plan = data['plan'] as String?;
      if (plan != null && plan.isNotEmpty) {
        await _localStorage.saveSelectedPlan(plan);
      }

      // Save user_id from API response if available
      final userId = data['user_id'];
      if (userId != null) {
        await _localStorage.saveUserId(userId.toString());
      }

      return verified;
    } catch (e) {
      rethrow;
    }
  }

  /// Re-check activation status from API and keep local state in sync.
  /// Calls the activation check endpoint immediately.
  /// Returns the final effective activation state.
  Future<bool> recheckActivationStatus() async {
    final verified = await checkDeviceStatus();
    await saveActivationStatus(verified);

    if (verified) {
      await _trialService.disableTrialMode();
    }

    return isActivated();
  }

  // Update user data on server.
  Future<bool> updateMyData(String fullName, String phone) async {
    try {
      final deviceId = await getDeviceId();
      return await _api.updateMyData(
        deviceId: deviceId,
        fullName: fullName,
        phone: phone,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ── Activation state checks ───────────────────────────────────────────

  // Check if license has expired using server-provided expires_at.
  Future<bool> isLicenseExpired() async {
    final expiresAt = await getExpiresAt();
    if (expiresAt == null || expiresAt.isEmpty) {
      // No expiration date means legacy activation (no expiration).
      return false;
    }
    try {
      final expirationDate = DateTime.parse(expiresAt).toUtc();
      final now = DateTime.now().toUtc();
      return now.isAfter(expirationDate) ||
          now.isAtSameMomentAs(expirationDate);
    } catch (e) {
      return false; // Parsing failure – fail-safe: not expired.
    }
  }

  // Check if device is activated.
  // Verifies tamper state → activation flag → expiry in order.
  Future<bool> isActivated() async {
    final tampered = await isTimeTampered();
    if (tampered) return false;

    final isVerified = await _localStorage.readActivationStatus();
    if (!isVerified) return false;

    final expired = await isLicenseExpired();
    if (expired) {
      await _localStorage.saveActivationVerified(false);
      return false;
    }
    return true;
  }

  // ── Agent data ────────────────────────────────────────────────────────

  Future<String> getAgentName() => _localStorage.getAgentName();
  Future<String> getAgentPhone() => _localStorage.getAgentPhone();
  Future<String> getUserId() => _localStorage.getUserId();
  Future<void> saveAgentName(String name) => _localStorage.saveAgentName(name);
  Future<void> saveAgentPhone(String phone) =>
      _localStorage.saveAgentPhone(phone);

  // Check if agent data exists.
  Future<bool> hasAgentData() async {
    final name = await getAgentName();
    final phone = await getAgentPhone();
    return name.isNotEmpty && phone.isNotEmpty;
  }

  // ── Trial mode ────────────────────────────────────────────────────────
  // All trial logic is owned by TrialModeService; these are public facades.

  Future<bool> hasTrialBeenUsedOnce() => _trialService.hasTrialBeenUsedOnce();
  Future<void> markTrialAsUsedOnce() => _trialService.markTrialAsUsedOnce();
  Future<void> enableTrialMode() => _trialService.enableTrialMode();
  Future<void> disableTrialMode() => _trialService.disableTrialMode();
  Future<bool> isTrialEnabled() => _trialService.isTrialEnabled();
  Future<bool> isTrialActive() => _trialService.isTrialActive();
  Future<int> getTrialPharmaciesLimit() => _trialService.getTrialPharmaciesLimit();
  Future<int> getTrialCompaniesLimit() => _trialService.getTrialCompaniesLimit();
  Future<int> getTrialMedicinesLimit() => _trialService.getTrialMedicinesLimit();
  Future<bool> isTrialMode() => _trialService.isTrialMode();
  Future<void> checkTrialLimitPharmacies() => _trialService.checkTrialLimitPharmacies();
  Future<void> checkTrialLimitCompanies() => _trialService.checkTrialLimitCompanies();
  Future<void> checkTrialLimitMedicines() => _trialService.checkTrialLimitMedicines();
  Future<bool> hasTrialExpired() => _trialService.hasTrialExpired();

  // ── Subscription request ──────────────────────────────────────────────

  // Send subscription activation request to backend API.
  // Called when user selects a plan and contact method.
  Future<bool> sendSubscriptionActivationRequest({
    required String deviceId,
    required String agentName,
    required String agentPhone,
    required String planId,
    required String contactMethod,
  }) async {
    try {
      final data = await _api.createDeviceWithPlan(
        deviceId: deviceId,
        agentName: agentName,
        agentPhone: agentPhone,
        planId: planId,
        contactMethod: contactMethod,
      );

      final serverTime = data['server_time'] as String?;
      if (serverTime != null && serverTime.isNotEmpty) {
        await _localStorage.saveTrustedTimeAndOffset(serverTime);
      }
      await _localStorage.setSubscriptionRequestSent(true);
      await _localStorage.saveActivationRequestState(planId);

      final isVerified = data['is_verified'];
      final expiresAt = data['expires_at'] as String?;
      final verified = isVerified == 1 || isVerified == true;
      if (verified && expiresAt != null && expiresAt.isNotEmpty) {
        await _localStorage.saveExpiresAt(expiresAt);
        await _localStorage.saveActivationVerified(true);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // Public method to save activation request state (called before API call).
  Future<void> saveActivationRequestState(String planId) =>
      _localStorage.saveActivationRequestState(planId);

  // Check if activation request was already sent.
  Future<bool> hasActivationRequestBeenSent() =>
      _localStorage.hasActivationRequestBeenSent();

  // Get selected plan from saved state.
  Future<String?> getSelectedPlan() => _localStorage.getSelectedPlan();

  // Get request timestamp.
  Future<String?> getRequestTimestamp() => _localStorage.getRequestTimestamp();

  // Check if subscription activation request was sent (legacy method).
  Future<bool> hasSubscriptionRequestBeenSent() =>
      _localStorage.hasSubscriptionRequestBeenSent();

  // ── Review ────────────────────────────────────────────────────────────

  Future<bool> hasReviewBeenSent() => _localStorage.hasReviewBeenSent();

  Future<void> markReviewSent() => _localStorage.markReviewSent();

  Future<bool> submitReview({required int stars, String? comment}) async {
    final deviceId = await getDeviceId();
    return _api.addReview(deviceId: deviceId, stars: stars, comment: comment);
  }
}
