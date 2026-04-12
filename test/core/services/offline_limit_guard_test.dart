import 'package:flutter_test/flutter_test.dart';
import 'package:smart_agent/core/services/offline_limit_guard.dart';

void main() {
  late OfflineLimitGuard guard;

  setUp(() {
    guard = OfflineLimitGuard();
  });

  // ── threshold constant sanity-check ─────────────────────────────────────
  group('limitHours constant', () {
    test('is 72 hours', () {
      expect(OfflineLimitGuard.limitHours, equals(72));
    });
  });

  // ── hasExceeded ──────────────────────────────────────────────────────────
  group('hasExceeded', () {
    test('0 hours offline → not exceeded', () {
      expect(guard.hasExceeded(Duration.zero), isFalse);
    });

    test('1 hour offline → not exceeded', () {
      expect(guard.hasExceeded(const Duration(hours: 1)), isFalse);
    });

    test('71 hours offline → not exceeded (one hour under limit)', () {
      expect(guard.hasExceeded(const Duration(hours: 71)), isFalse);
    });

    test('exactly 72 hours offline → NOT exceeded (condition is strictly >)', () {
      expect(guard.hasExceeded(const Duration(hours: 72)), isFalse);
    });

    test('73 hours offline → exceeded (one hour over limit)', () {
      expect(guard.hasExceeded(const Duration(hours: 73)), isTrue);
    });

    test('100 hours offline → exceeded', () {
      expect(guard.hasExceeded(const Duration(hours: 100)), isTrue);
    });

    test('very large duration (30 days) → exceeded', () {
      expect(guard.hasExceeded(const Duration(days: 30)), isTrue);
    });

    test('edge: 72 h and 1 minute → exceeded (inHours truncates: 72h1m = 72h)', () {
      // Duration(hours: 72, minutes: 1).inHours == 72, so still NOT exceeded.
      // This documents the truncation behavior of Duration.inHours.
      expect(
        guard.hasExceeded(const Duration(hours: 72, minutes: 1)),
        isFalse, // 72 is not > 72
      );
    });

    test('73 h exactly via minutes calculation', () {
      // 73 * 60 = 4380 minutes → inHours = 73 → exceeded
      expect(guard.hasExceeded(const Duration(minutes: 4380)), isTrue);
    });
  });

  // ── shouldClearExceededFlag ──────────────────────────────────────────────
  group('shouldClearExceededFlag', () {
    test('was NOT previously exceeded + within limit → no clear needed', () {
      expect(
        guard.shouldClearExceededFlag(const Duration(hours: 10), false),
        isFalse,
      );
    });

    test('was NOT previously exceeded + over limit → no clear needed', () {
      expect(
        guard.shouldClearExceededFlag(const Duration(hours: 80), false),
        isFalse,
      );
    });

    test('was previously exceeded + still over limit (73 h) → do NOT clear', () {
      expect(
        guard.shouldClearExceededFlag(const Duration(hours: 73), true),
        isFalse,
      );
    });

    test('was previously exceeded + exactly at limit (72 h) → SHOULD clear', () {
      // inHours == 72 which is <= 72, and previouslyExceeded is true → clear
      expect(
        guard.shouldClearExceededFlag(const Duration(hours: 72), true),
        isTrue,
      );
    });

    test('was previously exceeded + well within limit (0 h) → SHOULD clear', () {
      expect(
        guard.shouldClearExceededFlag(Duration.zero, true),
        isTrue,
      );
    });

    test('was previously exceeded + one hour under limit (71 h) → SHOULD clear', () {
      expect(
        guard.shouldClearExceededFlag(const Duration(hours: 71), true),
        isTrue,
      );
    });

    test('was previously exceeded + still over limit (large value) → do NOT clear', () {
      expect(
        guard.shouldClearExceededFlag(const Duration(days: 5), true),
        isFalse,
      );
    });
  });

  // ── combined hasExceeded / shouldClearExceededFlag lifecycle ────────────
  group('lifecycle: exceed → reconnect → clear flag', () {
    test('typical offline-to-online reconnection scenario', () {
      // Simulate going 80 hours offline
      const offlineDuration = Duration(hours: 80);
      expect(guard.hasExceeded(offlineDuration), isTrue,
          reason: 'after 80 h the limit must be exceeded');

      // Imagine app reconnects; new elapsed time since last sync is now 10 h.
      const afterReconnect = Duration(hours: 10);
      const previouslyExceeded = true; // flag was persisted

      expect(guard.hasExceeded(afterReconnect), isFalse,
          reason: 'after reconnect the limit is no longer exceeded');

      expect(
        guard.shouldClearExceededFlag(afterReconnect, previouslyExceeded),
        isTrue,
        reason: 'the persisted flag should be cleared now',
      );
    });
  });
}

