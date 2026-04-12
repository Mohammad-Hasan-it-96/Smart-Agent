import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';
import 'package:smart_agent/core/db/database_helper.dart';
import 'package:smart_agent/core/exceptions/trial_expired_exception.dart';
import 'package:smart_agent/core/services/activation_local_storage.dart';
import 'package:smart_agent/core/services/trial_mode_service.dart';

// ── Test doubles ──────────────────────────────────────────────────────────────

/// Mock for the persistence layer. Uses [implements] (not [extends]) so the
/// private [ActivationLocalStorage] internals are never invoked.
class MockActivationLocalStorage extends Mock
    implements ActivationLocalStorage {}

/// Mock for the DB helper.  [DatabaseHelper._init()] is never called because
/// [MockDatabaseHelper]'s superclass is [Mock], not [DatabaseHelper].
class MockDatabaseHelper extends Mock implements DatabaseHelper {}

/// Mock for the sqflite [Database] abstract class.
class MockDatabase extends Mock implements Database {}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  late MockActivationLocalStorage mockStorage;
  late MockDatabaseHelper mockDbHelper;
  late MockDatabase mockDb;
  late TrialModeService service;

  setUp(() {
    mockStorage = MockActivationLocalStorage();
    mockDbHelper = MockDatabaseHelper();
    mockDb = MockDatabase();
    service = TrialModeService(
      localStorage: mockStorage,
      db: mockDbHelper,
    );
  });

  // ── Shared stub helpers ────────────────────────────────────────────────────

  /// Stubs storage so that [isTrialMode()] returns true:
  /// device is not activated AND trial is active.
  void stubInTrialMode() {
    when(() => mockStorage.getActivationVerified())
        .thenAnswer((_) async => null);
    when(() => mockStorage.isTrialActive()).thenAnswer((_) async => true);
  }

  /// Stubs storage so that [isTrialMode()] returns false because the device
  /// is fully activated.
  void stubActivated() {
    when(() => mockStorage.getActivationVerified())
        .thenAnswer((_) async => true);
  }

  /// Stubs storage so that [isTrialMode()] returns false because trial is
  /// not active (and device is not activated).
  void stubTrialNotActive() {
    when(() => mockStorage.getActivationVerified())
        .thenAnswer((_) async => null);
    when(() => mockStorage.isTrialActive()).thenAnswer((_) async => false);
  }

  /// Stubs the calls made by [disableTrialMode()] so they don't throw.
  void stubDisableTrialMode() {
    when(() => mockStorage.setTrialEnabled(false)).thenAnswer((_) async {});
    when(() => mockStorage.setTrialActive(false)).thenAnswer((_) async {});
  }

  /// Stubs the [DatabaseHelper.database] getter and a COUNT query for [table]
  /// to return [count].
  void stubDbCount(String table, int count) {
    when(() => mockDbHelper.database).thenAnswer((_) async => mockDb);
    when(() =>
            mockDb.rawQuery('SELECT COUNT(*) as count FROM $table'))
        .thenAnswer((_) async => [
              {'count': count}
            ]);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // isTrialEnabled — thin delegation to storage
  // ════════════════════════════════════════════════════════════════════════════

  group('isTrialEnabled', () {
    test('returns true when storage reports enabled', () async {
      when(() => mockStorage.isTrialEnabled()).thenAnswer((_) async => true);
      expect(await service.isTrialEnabled(), isTrue);
    });

    test('returns false when storage reports disabled', () async {
      when(() => mockStorage.isTrialEnabled()).thenAnswer((_) async => false);
      expect(await service.isTrialEnabled(), isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // isTrialActive — thin delegation to storage
  // ════════════════════════════════════════════════════════════════════════════

  group('isTrialActive', () {
    test('returns true when storage reports active', () async {
      when(() => mockStorage.isTrialActive()).thenAnswer((_) async => true);
      expect(await service.isTrialActive(), isTrue);
    });

    test('returns false when storage reports inactive', () async {
      when(() => mockStorage.isTrialActive()).thenAnswer((_) async => false);
      expect(await service.isTrialActive(), isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // isTrialMode — compound check (activation flag + trial-active flag)
  // ════════════════════════════════════════════════════════════════════════════

  group('isTrialMode', () {
    test('returns false immediately when device is fully activated', () async {
      stubActivated();
      expect(await service.isTrialMode(), isFalse);
      // Short-circuits: isTrialActive() must NOT be queried.
      verifyNever(() => mockStorage.isTrialActive());
    });

    test('returns true when not activated (null) and trial is active', () async {
      when(() => mockStorage.getActivationVerified())
          .thenAnswer((_) async => null);
      when(() => mockStorage.isTrialActive()).thenAnswer((_) async => true);
      expect(await service.isTrialMode(), isTrue);
    });

    test('returns true when activation = false and trial is active', () async {
      when(() => mockStorage.getActivationVerified())
          .thenAnswer((_) async => false);
      when(() => mockStorage.isTrialActive()).thenAnswer((_) async => true);
      expect(await service.isTrialMode(), isTrue);
    });

    test('returns false when not activated but trial is not active', () async {
      stubTrialNotActive();
      expect(await service.isTrialMode(), isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // hasTrialBeenUsedOnce / markTrialAsUsedOnce — thin delegations
  // ════════════════════════════════════════════════════════════════════════════

  group('hasTrialBeenUsedOnce', () {
    test('returns true when storage reports used', () async {
      when(() => mockStorage.hasTrialBeenUsedOnce())
          .thenAnswer((_) async => true);
      expect(await service.hasTrialBeenUsedOnce(), isTrue);
    });

    test('returns false when storage reports not used', () async {
      when(() => mockStorage.hasTrialBeenUsedOnce())
          .thenAnswer((_) async => false);
      expect(await service.hasTrialBeenUsedOnce(), isFalse);
    });
  });

  group('markTrialAsUsedOnce', () {
    test('delegates to storage', () async {
      when(() => mockStorage.markTrialAsUsedOnce()).thenAnswer((_) async {});
      await service.markTrialAsUsedOnce();
      verify(() => mockStorage.markTrialAsUsedOnce()).called(1);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // enableTrialMode — orchestration: guard + enable flags + init limits + mark
  // ════════════════════════════════════════════════════════════════════════════

  group('enableTrialMode', () {
    test(
        'succeeds on first use: '
        'sets enabled+active, initialises limits, marks used', () async {
      when(() => mockStorage.hasTrialBeenUsedOnce())
          .thenAnswer((_) async => false);
      when(() => mockStorage.setTrialEnabled(true)).thenAnswer((_) async {});
      when(() => mockStorage.setTrialActive(true)).thenAnswer((_) async {});
      when(() => mockStorage.initializeTrialLimits()).thenAnswer((_) async {});
      when(() => mockStorage.markTrialAsUsedOnce()).thenAnswer((_) async {});

      await service.enableTrialMode();

      verify(() => mockStorage.setTrialEnabled(true)).called(1);
      verify(() => mockStorage.setTrialActive(true)).called(1);
      verify(() => mockStorage.initializeTrialLimits()).called(1);
      verify(() => mockStorage.markTrialAsUsedOnce()).called(1);
    });

    test('throws when trial has already been used once', () async {
      when(() => mockStorage.hasTrialBeenUsedOnce())
          .thenAnswer((_) async => true);

      await expectLater(
        service.enableTrialMode(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message contains Arabic error text',
            contains('تم استخدام النسخة التجريبية مسبقاً'),
          ),
        ),
      );

      // No side-effects should have occurred.
      verifyNever(() => mockStorage.setTrialEnabled(true));
      verifyNever(() => mockStorage.setTrialActive(true));
      verifyNever(() => mockStorage.initializeTrialLimits());
      verifyNever(() => mockStorage.markTrialAsUsedOnce());
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // disableTrialMode — sets both flags to false
  // ════════════════════════════════════════════════════════════════════════════

  group('disableTrialMode', () {
    test('sets trialEnabled = false and trialActive = false', () async {
      stubDisableTrialMode();

      await service.disableTrialMode();

      verify(() => mockStorage.setTrialEnabled(false)).called(1);
      verify(() => mockStorage.setTrialActive(false)).called(1);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // checkTrialLimitPharmacies
  // ════════════════════════════════════════════════════════════════════════════

  group('checkTrialLimitPharmacies', () {
    test('is a no-op when device is fully activated (not in trial mode)', () async {
      stubActivated();

      await service.checkTrialLimitPharmacies();

      verifyNever(() => mockDbHelper.database);
    });

    test('is a no-op when trial is not active', () async {
      stubTrialNotActive();

      await service.checkTrialLimitPharmacies();

      verifyNever(() => mockDbHelper.database);
    });

    test('completes without throwing when count is below limit', () async {
      stubInTrialMode();
      stubDbCount('pharmacies', 0);
      when(() => mockStorage.getTrialPharmaciesLimit())
          .thenAnswer((_) async => 1);

      await expectLater(service.checkTrialLimitPharmacies(), completes);
    });

    test(
        'throws TrialExpiredException(pharmacies) and disables trial '
        'when count equals limit (>= boundary)', () async {
      stubInTrialMode();
      stubDbCount('pharmacies', 1); // count == limit → triggers
      when(() => mockStorage.getTrialPharmaciesLimit())
          .thenAnswer((_) async => 1);
      stubDisableTrialMode();

      await expectLater(
        service.checkTrialLimitPharmacies(),
        throwsA(
          isA<TrialExpiredException>()
              .having((e) => e.limitType, 'limitType', equals('pharmacies')),
        ),
      );

      verify(() => mockStorage.setTrialEnabled(false)).called(1);
      verify(() => mockStorage.setTrialActive(false)).called(1);
    });

    test('throws TrialExpiredException and disables trial when count exceeds limit',
        () async {
      stubInTrialMode();
      stubDbCount('pharmacies', 5); // count > limit
      when(() => mockStorage.getTrialPharmaciesLimit())
          .thenAnswer((_) async => 1);
      stubDisableTrialMode();

      await expectLater(
        service.checkTrialLimitPharmacies(),
        throwsA(isA<TrialExpiredException>()),
      );

      verify(() => mockStorage.setTrialEnabled(false)).called(1);
      verify(() => mockStorage.setTrialActive(false)).called(1);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // checkTrialLimitCompanies
  // ════════════════════════════════════════════════════════════════════════════

  group('checkTrialLimitCompanies', () {
    test('is a no-op when not in trial mode', () async {
      stubActivated();

      await service.checkTrialLimitCompanies();

      verifyNever(() => mockDbHelper.database);
    });

    test('completes without throwing when count is below limit', () async {
      stubInTrialMode();
      stubDbCount('companies', 1);
      when(() => mockStorage.getTrialCompaniesLimit())
          .thenAnswer((_) async => 2);

      await expectLater(service.checkTrialLimitCompanies(), completes);
    });

    test(
        'throws TrialExpiredException(companies) and disables trial '
        'when count equals limit', () async {
      stubInTrialMode();
      stubDbCount('companies', 2); // count == limit
      when(() => mockStorage.getTrialCompaniesLimit())
          .thenAnswer((_) async => 2);
      stubDisableTrialMode();

      await expectLater(
        service.checkTrialLimitCompanies(),
        throwsA(
          isA<TrialExpiredException>()
              .having((e) => e.limitType, 'limitType', equals('companies')),
        ),
      );

      verify(() => mockStorage.setTrialEnabled(false)).called(1);
      verify(() => mockStorage.setTrialActive(false)).called(1);
    });

    test('throws TrialExpiredException when count exceeds limit', () async {
      stubInTrialMode();
      stubDbCount('companies', 10); // count >> limit
      when(() => mockStorage.getTrialCompaniesLimit())
          .thenAnswer((_) async => 2);
      stubDisableTrialMode();

      await expectLater(
        service.checkTrialLimitCompanies(),
        throwsA(isA<TrialExpiredException>()),
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // checkTrialLimitMedicines
  // ════════════════════════════════════════════════════════════════════════════

  group('checkTrialLimitMedicines', () {
    test('is a no-op when not in trial mode', () async {
      stubActivated();

      await service.checkTrialLimitMedicines();

      verifyNever(() => mockDbHelper.database);
    });

    test('completes without throwing when count is below limit', () async {
      stubInTrialMode();
      stubDbCount('medicines', 5);
      when(() => mockStorage.getTrialMedicinesLimit())
          .thenAnswer((_) async => 10);

      await expectLater(service.checkTrialLimitMedicines(), completes);
    });

    test(
        'throws TrialExpiredException(medicines) and disables trial '
        'when count equals limit', () async {
      stubInTrialMode();
      stubDbCount('medicines', 10); // count == limit
      when(() => mockStorage.getTrialMedicinesLimit())
          .thenAnswer((_) async => 10);
      stubDisableTrialMode();

      await expectLater(
        service.checkTrialLimitMedicines(),
        throwsA(
          isA<TrialExpiredException>()
              .having((e) => e.limitType, 'limitType', equals('medicines')),
        ),
      );

      verify(() => mockStorage.setTrialEnabled(false)).called(1);
      verify(() => mockStorage.setTrialActive(false)).called(1);
    });

    test('throws TrialExpiredException when count exceeds limit', () async {
      stubInTrialMode();
      stubDbCount('medicines', 50); // count >> limit
      when(() => mockStorage.getTrialMedicinesLimit())
          .thenAnswer((_) async => 10);
      stubDisableTrialMode();

      await expectLater(
        service.checkTrialLimitMedicines(),
        throwsA(isA<TrialExpiredException>()),
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // hasTrialExpired — orchestrates all three limit checks
  // ════════════════════════════════════════════════════════════════════════════

  group('hasTrialExpired', () {
    test('returns false immediately when not in trial mode', () async {
      stubActivated();

      expect(await service.hasTrialExpired(), isFalse);
      verifyNever(() => mockDbHelper.database);
    });

    test('returns false when all limits are within range', () async {
      stubInTrialMode();
      // All three DB stubs required (each checkTrialLimit* is called).
      when(() => mockDbHelper.database).thenAnswer((_) async => mockDb);
      when(() => mockDb.rawQuery('SELECT COUNT(*) as count FROM pharmacies'))
          .thenAnswer((_) async => [{'count': 0}]);
      when(() => mockStorage.getTrialPharmaciesLimit())
          .thenAnswer((_) async => 1);
      when(() => mockDb.rawQuery('SELECT COUNT(*) as count FROM companies'))
          .thenAnswer((_) async => [{'count': 1}]);
      when(() => mockStorage.getTrialCompaniesLimit())
          .thenAnswer((_) async => 2);
      when(() => mockDb.rawQuery('SELECT COUNT(*) as count FROM medicines'))
          .thenAnswer((_) async => [{'count': 5}]);
      when(() => mockStorage.getTrialMedicinesLimit())
          .thenAnswer((_) async => 10);

      expect(await service.hasTrialExpired(), isFalse);
    });

    test('returns true when pharmacies limit is reached (short-circuits)', () async {
      // Pharmacies check fires first and throws — companies & medicines are skipped.
      stubInTrialMode();
      stubDbCount('pharmacies', 1); // count == limit
      when(() => mockStorage.getTrialPharmaciesLimit())
          .thenAnswer((_) async => 1);
      stubDisableTrialMode();

      expect(await service.hasTrialExpired(), isTrue);
      verifyNever(() =>
          mockDb.rawQuery('SELECT COUNT(*) as count FROM companies'));
      verifyNever(() =>
          mockDb.rawQuery('SELECT COUNT(*) as count FROM medicines'));
    });

    test('returns true when companies limit is reached (pharmacies were fine)',
        () async {
      stubInTrialMode();
      when(() => mockDbHelper.database).thenAnswer((_) async => mockDb);
      // Pharmacies below limit
      when(() => mockDb.rawQuery('SELECT COUNT(*) as count FROM pharmacies'))
          .thenAnswer((_) async => [{'count': 0}]);
      when(() => mockStorage.getTrialPharmaciesLimit())
          .thenAnswer((_) async => 1);
      // Companies at limit
      when(() => mockDb.rawQuery('SELECT COUNT(*) as count FROM companies'))
          .thenAnswer((_) async => [{'count': 2}]);
      when(() => mockStorage.getTrialCompaniesLimit())
          .thenAnswer((_) async => 2);
      stubDisableTrialMode();

      expect(await service.hasTrialExpired(), isTrue);
      // Medicines check should not have been reached.
      verifyNever(() =>
          mockDb.rawQuery('SELECT COUNT(*) as count FROM medicines'));
    });

    test(
        'returns true when medicines limit is reached '
        '(pharmacies and companies were fine)', () async {
      stubInTrialMode();
      when(() => mockDbHelper.database).thenAnswer((_) async => mockDb);
      // Pharmacies below limit
      when(() => mockDb.rawQuery('SELECT COUNT(*) as count FROM pharmacies'))
          .thenAnswer((_) async => [{'count': 0}]);
      when(() => mockStorage.getTrialPharmaciesLimit())
          .thenAnswer((_) async => 1);
      // Companies below limit
      when(() => mockDb.rawQuery('SELECT COUNT(*) as count FROM companies'))
          .thenAnswer((_) async => [{'count': 0}]);
      when(() => mockStorage.getTrialCompaniesLimit())
          .thenAnswer((_) async => 2);
      // Medicines at limit
      when(() => mockDb.rawQuery('SELECT COUNT(*) as count FROM medicines'))
          .thenAnswer((_) async => [{'count': 10}]);
      when(() => mockStorage.getTrialMedicinesLimit())
          .thenAnswer((_) async => 10);
      stubDisableTrialMode();

      expect(await service.hasTrialExpired(), isTrue);
    });

    test(
        'returns false (not TrialExpiredException) when a non-trial exception '
        'is thrown — documents the catch-filter behavior', () async {
      // In trial mode, but DB access blows up with a generic exception.
      // The catch block does: return e is TrialExpiredException → false.
      stubInTrialMode();
      when(() => mockDbHelper.database)
          .thenThrow(Exception('DB unavailable'));

      expect(await service.hasTrialExpired(), isFalse);
    });
  });
}

