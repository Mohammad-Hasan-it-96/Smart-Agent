import '../db/database_helper.dart';
import '../exceptions/trial_expired_exception.dart';
import 'activation_local_storage.dart';

/// Owns all trial-mode business logic: enabling/disabling trial, checking
/// whether the trial is active, and enforcing per-entity limits.
///
/// Persistence is delegated to [ActivationLocalStorage].
/// DB record counts are read via the injected [DatabaseHelper].
///
/// [ActivationService] is the public facade; it delegates all trial-related
/// calls to this class.
class TrialModeService {
  final ActivationLocalStorage _localStorage;
  final DatabaseHelper _db;

  TrialModeService({
    required ActivationLocalStorage localStorage,
    required DatabaseHelper db,
  })  : _localStorage = localStorage,
        _db = db;

  // ── Trial-used-once flag (tamper-proof via local file) ────────────────

  Future<bool> hasTrialBeenUsedOnce() =>
      _localStorage.hasTrialBeenUsedOnce();

  Future<void> markTrialAsUsedOnce() =>
      _localStorage.markTrialAsUsedOnce();

  // ── Enable / disable ──────────────────────────────────────────────────

  /// Activates trial mode for the first time.
  ///
  /// Throws if the trial has already been used on this device.
  Future<void> enableTrialMode() async {
    final usedOnce = await hasTrialBeenUsedOnce();
    if (usedOnce) {
      throw Exception('تم استخدام النسخة التجريبية مسبقاً');
    }
    await _localStorage.setTrialEnabled(true);
    await _localStorage.setTrialActive(true);
    await _localStorage.initializeTrialLimits();
    await markTrialAsUsedOnce();
  }

  /// Deactivates trial mode (called when a limit is reached or activation
  /// is confirmed).
  Future<void> disableTrialMode() async {
    await _localStorage.setTrialEnabled(false);
    await _localStorage.setTrialActive(false);
  }

  // ── State queries ─────────────────────────────────────────────────────

  Future<bool> isTrialEnabled() => _localStorage.isTrialEnabled();
  Future<bool> isTrialActive() => _localStorage.isTrialActive();

  /// Returns `true` only when the device is NOT activated and trial mode
  /// is currently active.
  Future<bool> isTrialMode() async {
    final verified = await _localStorage.getActivationVerified();
    if (verified == true) return false; // fully activated – not in trial
    return _localStorage.isTrialActive();
  }

  // ── Limit queries ─────────────────────────────────────────────────────

  Future<int> getTrialPharmaciesLimit() =>
      _localStorage.getTrialPharmaciesLimit();
  Future<int> getTrialCompaniesLimit() =>
      _localStorage.getTrialCompaniesLimit();
  Future<int> getTrialMedicinesLimit() =>
      _localStorage.getTrialMedicinesLimit();

  // ── Limit enforcement ─────────────────────────────────────────────────

  /// Throws [TrialExpiredException] if the pharmacy count has reached the
  /// trial limit. No-op when not in trial mode.
  Future<void> checkTrialLimitPharmacies() async {
    if (!await isTrialMode()) return;
    final db = await _db.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM pharmacies');
    final count = result.first['count'] as int;
    final limit = await getTrialPharmaciesLimit();
    if (count >= limit) {
      await disableTrialMode();
      throw TrialExpiredException('pharmacies');
    }
  }

  /// Throws [TrialExpiredException] if the company count has reached the
  /// trial limit. No-op when not in trial mode.
  Future<void> checkTrialLimitCompanies() async {
    if (!await isTrialMode()) return;
    final db = await _db.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM companies');
    final count = result.first['count'] as int;
    final limit = await getTrialCompaniesLimit();
    if (count >= limit) {
      await disableTrialMode();
      throw TrialExpiredException('companies');
    }
  }

  /// Throws [TrialExpiredException] if the medicine count has reached the
  /// trial limit. No-op when not in trial mode.
  Future<void> checkTrialLimitMedicines() async {
    if (!await isTrialMode()) return;
    final db = await _db.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM medicines');
    final count = result.first['count'] as int;
    final limit = await getTrialMedicinesLimit();
    if (count >= limit) {
      await disableTrialMode();
      throw TrialExpiredException('medicines');
    }
  }

  /// Returns `true` if any trial limit has already been reached.
  /// Returns `false` when not in trial mode or all limits are still within
  /// range.
  Future<bool> hasTrialExpired() async {
    if (!await isTrialMode()) return false;
    try {
      await checkTrialLimitPharmacies();
      await checkTrialLimitCompanies();
      await checkTrialLimitMedicines();
      return false;
    } catch (e) {
      return e is TrialExpiredException;
    }
  }
}

