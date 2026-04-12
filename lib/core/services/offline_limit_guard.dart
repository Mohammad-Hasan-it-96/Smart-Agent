/// Pure offline-limit evaluation logic.
///
/// This class owns only the threshold constant and the two boolean
/// decisions derived from elapsed-time arithmetic.
/// It has no external dependencies — no storage, no platform calls —
/// making it trivially unit-testable without mocks.
///
/// Storage reads/writes and orchestration stay in [ActivationService].
class OfflineLimitGuard {
  /// Hours without a successful server contact before the app must reconnect.
  static const int limitHours = 72;

  /// Returns `true` if the time elapsed since the last online sync exceeds
  /// the allowed limit, meaning the user must reconnect now.
  bool hasExceeded(Duration timeSinceLastSync) =>
      timeSinceLastSync.inHours > limitHours;

  /// Returns `true` when the offline-exceeded flag was previously set **and**
  /// the elapsed time has since come back within the allowed window.
  ///
  /// When this returns `true` the caller should clear the persisted flag and
  /// report the limit as no longer exceeded.
  bool shouldClearExceededFlag(
    Duration timeSinceLastSync,
    bool previouslyExceeded,
  ) =>
      previouslyExceeded && timeSinceLastSync.inHours <= limitHours;
}

