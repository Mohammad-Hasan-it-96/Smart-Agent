/// Pure tamper-detection logic for clock-rollback attacks.
///
/// This class owns only arithmetic and comparison rules.
/// It has no external dependencies — no storage, no platform calls.
/// That makes it trivially unit-testable without mocks.
///
/// Storage reads/writes and orchestration stay in [ActivationService].
class TimeTamperGuard {
  /// Maximum allowed backward drift (in minutes) before tampering is declared.
  ///
  /// If the adjusted device clock lags more than this behind the last trusted
  /// server time, the device time is considered manipulated.
  static const int thresholdMinutes = 5;

  /// Returns `true` if the device clock appears to have been rolled back.
  ///
  /// Parameters:
  ///   [lastTrustedTime]  – last server-verified UTC timestamp.
  ///   [deviceTime]       – current device time in UTC.
  ///   [timeOffsetSeconds]– server-minus-device offset (seconds) recorded at
  ///                        the last successful online sync.
  ///
  /// Logic:
  ///   1. Apply the known offset to the current device time to get an adjusted
  ///      clock that compensates for systematic device-vs-server skew.
  ///   2. Compute drift = lastTrustedTime − adjustedDeviceTime.
  ///   3. If drift > [thresholdMinutes], the clock went backwards → tampered.
  bool isTampered({
    required DateTime lastTrustedTime,
    required DateTime deviceTime,
    required int timeOffsetSeconds,
  }) {
    final adjustedDeviceTime = deviceTime.add(Duration(seconds: timeOffsetSeconds));
    final drift = lastTrustedTime.difference(adjustedDeviceTime);
    return drift.inMinutes > thresholdMinutes;
  }
}

