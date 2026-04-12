import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns every SharedPreferences key and local-file operation that belongs to
/// activation, agent data, and trial state.
///
/// `ActivationService` is the public facade; it delegates all persistence
/// reads/writes to this class.
class ActivationLocalStorage {
  // ── Activation keys ─────────────────────────────────────────────────
  static const String activationKey = 'is_activated';
  static const String activationVerifiedKey = 'activation_verified';
  static const String activationCalledKey = 'activation_api_called';
  static const String subscriptionRequestSentKey = 'subscription_request_sent';
  static const String activationRequestedKey = 'activation_requested';
  static const String selectedPlanKey = 'selected_plan';
  static const String requestTimestampKey = 'request_timestamp';

  // ── Expiry ───────────────────────────────────────────────────────────
  static const String expiresAtKey = 'expires_at';
  static const String expiresAtFileName = 'activation_expires_at.txt';

  // ── Time-guard ───────────────────────────────────────────────────────
  static const String lastTrustedTimeKey = 'last_trusted_time';
  static const String timeOffsetKey = 'time_offset_seconds';
  static const String timeTamperedKey = 'time_tampered';

  // ── Offline-limit ────────────────────────────────────────────────────
  static const String lastOnlineSyncKey = 'last_online_sync';
  static const String offlineLimitExceededKey = 'offline_limit_exceeded';

  // ── Agent ────────────────────────────────────────────────────────────
  static const String agentNameKey = 'agent_full_name';
  static const String agentPhoneKey = 'agent_phone';

  // ── Trial ────────────────────────────────────────────────────────────
  static const String trialEnabledKey = 'trial_enabled';
  static const String trialActiveKey = 'trial_active';
  static const String trialPharmaciesLimitKey = 'trial_limit_pharmacies';
  static const String trialCompaniesLimitKey = 'trial_limit_companies';
  static const String trialMedicinesLimitKey = 'trial_limit_medicines';
  static const String trialUsedOnceFileName = 'trial_used_once.flag';

  // ═══════════════════════════════════════════════════════════════════
  // Activation status
  // ═══════════════════════════════════════════════════════════════════

  /// Persist verified flag to both the new key and the legacy key for
  /// backward compatibility.
  Future<void> saveActivationVerified(bool verified) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(activationVerifiedKey, verified);
    await prefs.setBool(activationKey, verified); // legacy key
  }

  Future<bool?> getActivationVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(activationVerifiedKey);
  }

  /// Writes both keys atomically (used by saveActivationStatus public path).
  Future<void> saveActivationStatus(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(activationKey, value);
    await prefs.setBool(activationVerifiedKey, value);
  }

  /// Reads activation status, checking new key first then falling back to
  /// legacy key – mirrors the original `isActivated()` prefs read.
  Future<bool> readActivationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final verified = prefs.getBool(activationVerifiedKey);
    return verified ?? prefs.getBool(activationKey) ?? false;
  }

  Future<void> setActivationCalled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(activationCalledKey, true);
  }

  Future<bool> hasActivationBeenCalled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(activationCalledKey) ?? false;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Expiry
  // ═══════════════════════════════════════════════════════════════════

  /// Saves the expiry date to SharedPreferences AND a local file for
  /// redundancy/security.
  Future<void> saveExpiresAt(String expiresAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(expiresAtKey, expiresAt);
    try {
      final dir = await getApplicationDocumentsDirectory();
      await File('${dir.path}/$expiresAtFileName').writeAsString(expiresAt);
    } catch (_) {
      // File write failure is non-critical; SharedPreferences is primary.
    }
  }

  /// Returns expiry date from SharedPreferences, with local-file fallback.
  Future<String?> getExpiresAt() async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = prefs.getString(expiresAtKey);
    if (expiresAt != null && expiresAt.isNotEmpty) return expiresAt;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$expiresAtFileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          await prefs.setString(expiresAtKey, content); // cache in prefs
          return content;
        }
      }
    } catch (_) {}

    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Trusted time & time-tamper guard
  // ═══════════════════════════════════════════════════════════════════

  /// Calculates and persists the server/device time offset; resets the
  /// tamper flag on every successful server sync.
  Future<void> saveTrustedTimeAndOffset(String serverTimeString) async {
    try {
      final serverTime = DateTime.parse(serverTimeString).toUtc();
      final deviceTime = DateTime.now().toUtc();
      final offsetSeconds = serverTime.difference(deviceTime).inSeconds;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(lastTrustedTimeKey, serverTime.toIso8601String());
      await prefs.setInt(timeOffsetKey, offsetSeconds);
      await prefs.setBool(timeTamperedKey, false);
    } catch (_) {
      // Parsing failure – do not update trusted time.
    }
  }

  Future<DateTime?> getLastTrustedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(lastTrustedTimeKey);
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s).toUtc();
    } catch (_) {
      return null;
    }
  }

  Future<int> getTimeOffset() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(timeOffsetKey) ?? 0;
  }

  Future<void> setTimeTampered(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(timeTamperedKey, value);
  }

  Future<bool> isTimeTampered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(timeTamperedKey) ?? false;
  }

  Future<void> clearTimeTamperingFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(timeTamperedKey, false);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Online sync & offline limit
  // ═══════════════════════════════════════════════════════════════════

  /// Records a successful server contact and clears the offline-exceeded flag.
  Future<void> updateLastOnlineSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        lastOnlineSyncKey, DateTime.now().toUtc().toIso8601String());
    await prefs.setBool(offlineLimitExceededKey, false);
  }

  Future<DateTime?> getLastOnlineSync() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(lastOnlineSyncKey);
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s).toUtc();
    } catch (_) {
      return null;
    }
  }

  Future<void> setOfflineLimitExceeded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(offlineLimitExceededKey, value);
  }

  Future<bool> hasOfflineLimitExceeded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(offlineLimitExceededKey) ?? false;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Agent data
  // ═══════════════════════════════════════════════════════════════════

  Future<String> getAgentName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(agentNameKey) ?? '';
  }

  Future<String> getAgentPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(agentPhoneKey) ?? '';
  }

  Future<void> saveAgentName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(agentNameKey, name);
  }

  Future<void> saveAgentPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(agentPhoneKey, phone);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Trial mode
  // ═══════════════════════════════════════════════════════════════════

  /// Writes default trial-limit values only if they are not already set.
  Future<void> initializeTrialLimits() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(trialPharmaciesLimitKey) == null) {
      await prefs.setInt(trialPharmaciesLimitKey, 1);
    }
    if (prefs.getInt(trialCompaniesLimitKey) == null) {
      await prefs.setInt(trialCompaniesLimitKey, 2);
    }
    if (prefs.getInt(trialMedicinesLimitKey) == null) {
      await prefs.setInt(trialMedicinesLimitKey, 10);
    }
  }

  /// Returns true if the tamper-proof trial-used-once flag file exists.
  Future<bool> hasTrialBeenUsedOnce() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$trialUsedOnceFileName').exists();
    } catch (_) {
      return false;
    }
  }

  /// Creates the tamper-proof trial-used-once flag file.
  Future<void> markTrialAsUsedOnce() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      await File('${dir.path}/$trialUsedOnceFileName')
          .writeAsString('trial_used');
    } catch (_) {
      // Ignore – best-effort tamper protection.
    }
  }

  Future<void> setTrialEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(trialEnabledKey, value);
  }

  Future<void> setTrialActive(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(trialActiveKey, value);
  }

  Future<bool> isTrialEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(trialEnabledKey) ?? false;
  }

  Future<bool> isTrialActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(trialActiveKey) ?? false;
  }

  Future<int> getTrialPharmaciesLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(trialPharmaciesLimitKey) ?? 1;
  }

  Future<int> getTrialCompaniesLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(trialCompaniesLimitKey) ?? 2;
  }

  Future<int> getTrialMedicinesLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(trialMedicinesLimitKey) ?? 10;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Activation-request state
  // ═══════════════════════════════════════════════════════════════════

  Future<void> saveActivationRequestState(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(activationRequestedKey, true);
    await prefs.setString(selectedPlanKey, planId);
    await prefs.setString(
        requestTimestampKey, DateTime.now().toIso8601String());
  }

  Future<bool> hasActivationRequestBeenSent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(activationRequestedKey) ?? false;
  }

  Future<void> saveSelectedPlan(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(selectedPlanKey, planId);
  }

  Future<String?> getSelectedPlan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(selectedPlanKey);
  }

  Future<String?> getRequestTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(requestTimestampKey);
  }

  Future<void> setSubscriptionRequestSent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(subscriptionRequestSentKey, value);
  }

  Future<bool> hasSubscriptionRequestBeenSent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(subscriptionRequestSentKey) ?? false;
  }
}

