import 'package:flutter_test/flutter_test.dart';
import 'package:smart_agent/core/services/time_tamper_guard.dart';

void main() {
  late TimeTamperGuard guard;

  setUp(() {
    guard = TimeTamperGuard();
  });

  // Anchor: a fixed "last trusted" time that tests revolve around.
  final trusted = DateTime.utc(2026, 1, 1, 12, 0, 0);

  // ── threshold constant sanity-check ─────────────────────────────────────
  group('thresholdMinutes constant', () {
    test('is 5 minutes', () {
      expect(TimeTamperGuard.thresholdMinutes, equals(5));
    });
  });

  // ── isTampered – clean cases ─────────────────────────────────────────────
  group('isTampered – not tampered', () {
    test('device time equals trusted time (zero drift)', () {
      expect(
        guard.isTampered(
          lastTrustedTime: trusted,
          deviceTime: trusted,
          timeOffsetSeconds: 0,
        ),
        isFalse,
      );
    });

    test('device time is ahead of trusted time (negative drift)', () {
      final deviceAhead = trusted.add(const Duration(minutes: 10));
      expect(
        guard.isTampered(
          lastTrustedTime: trusted,
          deviceTime: deviceAhead,
          timeOffsetSeconds: 0,
        ),
        isFalse,
      );
    });

    test('drift is exactly at threshold (5 minutes) – NOT exceeded (> not >=)', () {
      // drift == thresholdMinutes → false because condition is strictly >
      final deviceBehind = trusted.subtract(const Duration(minutes: 5));
      expect(
        guard.isTampered(
          lastTrustedTime: trusted,
          deviceTime: deviceBehind,
          timeOffsetSeconds: 0,
        ),
        isFalse,
      );
    });

    test('drift is 4 minutes – well within threshold', () {
      final deviceBehind = trusted.subtract(const Duration(minutes: 4));
      expect(
        guard.isTampered(
          lastTrustedTime: trusted,
          deviceTime: deviceBehind,
          timeOffsetSeconds: 0,
        ),
        isFalse,
      );
    });
  });

  // ── isTampered – tampered cases ──────────────────────────────────────────
  group('isTampered – tampered', () {
    test('drift is 6 minutes (one minute over threshold)', () {
      final deviceBehind = trusted.subtract(const Duration(minutes: 6));
      expect(
        guard.isTampered(
          lastTrustedTime: trusted,
          deviceTime: deviceBehind,
          timeOffsetSeconds: 0,
        ),
        isTrue,
      );
    });

    test('drift is 1 hour (large rollback)', () {
      final deviceBehind = trusted.subtract(const Duration(hours: 1));
      expect(
        guard.isTampered(
          lastTrustedTime: trusted,
          deviceTime: deviceBehind,
          timeOffsetSeconds: 0,
        ),
        isTrue,
      );
    });

    test('drift is 24 hours (very large rollback)', () {
      final deviceBehind = trusted.subtract(const Duration(hours: 24));
      expect(
        guard.isTampered(
          lastTrustedTime: trusted,
          deviceTime: deviceBehind,
          timeOffsetSeconds: 0,
        ),
        isTrue,
      );
    });
  });

  // ── isTampered – offset compensation ────────────────────────────────────
  group('isTampered – timeOffsetSeconds interaction', () {
    test('positive offset corrects device time forward, removing perceived drift', () {
      // Device is 10 minutes behind trusted time.
      // A +600 s offset advances the adjusted clock by 10 minutes → drift = 0.
      final deviceBehind = trusted.subtract(const Duration(minutes: 10));
      expect(
        guard.isTampered(
          lastTrustedTime: trusted,
          deviceTime: deviceBehind,
          timeOffsetSeconds: 600, // +10 minutes
        ),
        isFalse,
      );
    });

    test('negative offset shifts adjusted clock backward, causing tamper detection', () {
      // Device time equals trusted time, but a –360 s offset pushes the adjusted
      // clock 6 minutes behind → drift = 6 min > threshold.
      expect(
        guard.isTampered(
          lastTrustedTime: trusted,
          deviceTime: trusted,
          timeOffsetSeconds: -360, // –6 minutes
        ),
        isTrue,
      );
    });

    test('positive offset over-corrects: adjusted clock ahead, drift negative → not tampered', () {
      // Device is 3 minutes behind trusted, but offset is +10 min.
      // adjustedTime = trusted – 3 min + 10 min = trusted + 7 min → drift negative.
      final deviceBehind = trusted.subtract(const Duration(minutes: 3));
      expect(
        guard.isTampered(
          lastTrustedTime: trusted,
          deviceTime: deviceBehind,
          timeOffsetSeconds: 600,
        ),
        isFalse,
      );
    });

    test('zero offset has no effect on outcome', () {
      final deviceBehind = trusted.subtract(const Duration(minutes: 10));
      expect(
        guard.isTampered(
          lastTrustedTime: trusted,
          deviceTime: deviceBehind,
          timeOffsetSeconds: 0,
        ),
        isTrue,
      );
    });
  });
}

