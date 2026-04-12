import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smart_agent/core/services/activation_local_storage.dart';
import 'package:smart_agent/core/services/activation_service.dart';
import 'package:smart_agent/core/services/device_api_repository.dart';
import 'package:smart_agent/core/services/device_identity_service.dart';
import 'package:smart_agent/core/services/offline_limit_guard.dart';
import 'package:smart_agent/core/services/time_tamper_guard.dart';
import 'package:smart_agent/core/services/trial_mode_service.dart';

// ── Test doubles ──────────────────────────────────────────────────────────────

class MockActivationLocalStorage extends Mock
    implements ActivationLocalStorage {}

class MockDeviceIdentityService extends Mock implements DeviceIdentityService {}

class MockDeviceApiRepository extends Mock implements DeviceApiRepository {}

/// Guards are pure-logic classes; we still mock them so DateTime.now() inside
/// ActivationService does not affect test outcomes.
class MockTimeTamperGuard extends Mock implements TimeTamperGuard {}

class MockOfflineLimitGuard extends Mock implements OfflineLimitGuard {}

/// TrialModeService is mocked at the service level: ActivationService
/// delegates all trial calls to it, so we verify delegation only.
class MockTrialModeService extends Mock implements TrialModeService {}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  // Duration is not in mocktail's built-in primitive fallback table.
  // Without this, any() on Duration parameters throws Bad state, which leaves
  // mocktail's verification-mode flag dirty and corrupts all subsequent when()
  // calls in later tests.
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  late MockActivationLocalStorage mockStorage;
  late MockDeviceIdentityService mockDeviceIdentity;
  late MockDeviceApiRepository mockApi;
  late MockTimeTamperGuard mockTamperGuard;
  late MockOfflineLimitGuard mockOfflineGuard;
  late MockTrialModeService mockTrialService;
  late ActivationService service;

  setUp(() {
    mockStorage = MockActivationLocalStorage();
    mockDeviceIdentity = MockDeviceIdentityService();
    mockApi = MockDeviceApiRepository();
    mockTamperGuard = MockTimeTamperGuard();
    mockOfflineGuard = MockOfflineLimitGuard();
    mockTrialService = MockTrialModeService();

    service = ActivationService(
      localStorage: mockStorage,
      deviceIdentity: mockDeviceIdentity,
      api: mockApi,
      tamperGuard: mockTamperGuard,
      offlineGuard: mockOfflineGuard,
      trialService: mockTrialService,
    );
  });

  // ── Shared stub helpers ───────────────────────────────────────────────────

  /// Stubs [isActivated()] to return [activated].
  /// Chains: isTimeTampered → false, readActivationStatus → [activated],
  /// and (when activated=true) getExpiresAt → null (legacy/no expiry).
  void stubIsActivated({required bool activated}) {
    when(() => mockStorage.isTimeTampered()).thenAnswer((_) async => false);
    when(() => mockStorage.readActivationStatus())
        .thenAnswer((_) async => activated);
    if (activated) {
      // No expiry date → not expired → isActivated() returns true.
      when(() => mockStorage.getExpiresAt()).thenAnswer((_) async => null);
    }
  }

  /// Stubs the standard [checkDeviceStatus()] call sequence.
  ///
  /// Provides a complete device-check response for the given [verified] state.
  /// Always supplies a device ID and valid agent data so the early-return guard
  /// is not triggered.
  void stubCheckDevice({
    required bool verified,
    String? serverTime,
    String? expiresAt,
    String? plan,
  }) {
    when(() => mockDeviceIdentity.getDeviceId())
        .thenAnswer((_) async => 'device123');
    when(() => mockStorage.getAgentName()).thenAnswer((_) async => 'Ahmed Ali');
    when(() => mockStorage.getAgentPhone())
        .thenAnswer((_) async => '0501234567');
    when(() => mockApi.checkDevice(deviceId: any(named: 'deviceId')))
        .thenAnswer((_) async => {
              'is_verified': verified ? 1 : 0,
              'server_time': serverTime,
              'expires_at': expiresAt,
              'plan': plan,
            });
    when(() => mockStorage.updateLastOnlineSync()).thenAnswer((_) async {});
    when(() => mockStorage.saveActivationVerified(verified))
        .thenAnswer((_) async {});
    if (serverTime != null) {
      when(() => mockStorage.saveTrustedTimeAndOffset(any()))
          .thenAnswer((_) async {});
    }
    if (expiresAt != null) {
      when(() => mockStorage.saveExpiresAt(any())).thenAnswer((_) async {});
    }
    if (plan != null) {
      when(() => mockStorage.saveSelectedPlan(any())).thenAnswer((_) async {});
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // isActivated — three-gate check: tamper → verified → expiry
  // ════════════════════════════════════════════════════════════════════════════

  group('isActivated', () {
    test('returns false immediately when time tampering is detected', () async {
      when(() => mockStorage.isTimeTampered()).thenAnswer((_) async => true);

      expect(await service.isActivated(), isFalse);

      // Short-circuits: activation status must NOT be queried.
      verifyNever(() => mockStorage.readActivationStatus());
      verifyNever(() => mockStorage.getExpiresAt());
    });

    test('returns false when not tampered but activation is not verified',
        () async {
      when(() => mockStorage.isTimeTampered()).thenAnswer((_) async => false);
      when(() => mockStorage.readActivationStatus())
          .thenAnswer((_) async => false);

      expect(await service.isActivated(), isFalse);

      // Short-circuits: expiry must NOT be queried.
      verifyNever(() => mockStorage.getExpiresAt());
    });

    test(
        'returns false and persists verified=false when activation is verified '
        'but license has expired', () async {
      when(() => mockStorage.isTimeTampered()).thenAnswer((_) async => false);
      when(() => mockStorage.readActivationStatus())
          .thenAnswer((_) async => true);
      // Clearly past date → expired.
      when(() => mockStorage.getExpiresAt())
          .thenAnswer((_) async => '2020-01-01T00:00:00Z');
      when(() => mockStorage.saveActivationVerified(false))
          .thenAnswer((_) async {});

      expect(await service.isActivated(), isFalse);
      verify(() => mockStorage.saveActivationVerified(false)).called(1);
    });

    test(
        'returns true when not tampered, verified, and license is not yet '
        'expired', () async {
      when(() => mockStorage.isTimeTampered()).thenAnswer((_) async => false);
      when(() => mockStorage.readActivationStatus())
          .thenAnswer((_) async => true);
      // Clearly future date → not expired.
      when(() => mockStorage.getExpiresAt())
          .thenAnswer((_) async => '2030-01-01T00:00:00Z');

      expect(await service.isActivated(), isTrue);
      verifyNever(() => mockStorage.saveActivationVerified(any()));
    });

    test('returns true when not tampered, verified, and no expiry date stored '
        '(legacy activation)', () async {
      when(() => mockStorage.isTimeTampered()).thenAnswer((_) async => false);
      when(() => mockStorage.readActivationStatus())
          .thenAnswer((_) async => true);
      when(() => mockStorage.getExpiresAt()).thenAnswer((_) async => null);

      expect(await service.isActivated(), isTrue);
      verifyNever(() => mockStorage.saveActivationVerified(any()));
    });

    test('returns true when not tampered, verified, and expiry date is empty '
        'string (legacy activation)', () async {
      when(() => mockStorage.isTimeTampered()).thenAnswer((_) async => false);
      when(() => mockStorage.readActivationStatus())
          .thenAnswer((_) async => true);
      when(() => mockStorage.getExpiresAt()).thenAnswer((_) async => '');

      expect(await service.isActivated(), isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // isLicenseExpired — expiry-date comparison logic
  // ════════════════════════════════════════════════════════════════════════════

  group('isLicenseExpired', () {
    test('returns false when no expiry date is stored (null)', () async {
      when(() => mockStorage.getExpiresAt()).thenAnswer((_) async => null);

      expect(await service.isLicenseExpired(), isFalse);
    });

    test('returns false when expiry date is empty string', () async {
      when(() => mockStorage.getExpiresAt()).thenAnswer((_) async => '');

      expect(await service.isLicenseExpired(), isFalse);
    });

    test('returns true when expiry date is in the past', () async {
      when(() => mockStorage.getExpiresAt())
          .thenAnswer((_) async => '2020-06-15T12:00:00Z');

      expect(await service.isLicenseExpired(), isTrue);
    });

    test('returns false when expiry date is in the future', () async {
      when(() => mockStorage.getExpiresAt())
          .thenAnswer((_) async => '2035-01-01T00:00:00Z');

      expect(await service.isLicenseExpired(), isFalse);
    });

    test(
        'returns false when expiry string cannot be parsed '
        '(fail-safe: not expired)', () async {
      when(() => mockStorage.getExpiresAt())
          .thenAnswer((_) async => 'not-a-valid-date');

      expect(await service.isLicenseExpired(), isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // checkTimeTampering — delegates detection to TimeTamperGuard, then
  // applies storage side-effects when tampering is confirmed
  // ════════════════════════════════════════════════════════════════════════════

  group('checkTimeTampering', () {
    test('returns false and has no side-effects when no trusted time is stored',
        () async {
      when(() => mockStorage.getLastTrustedTime())
          .thenAnswer((_) async => null);

      expect(await service.checkTimeTampering(), isFalse);

      verifyNever(() => mockTamperGuard.isTampered(
            lastTrustedTime: any(named: 'lastTrustedTime'),
            deviceTime: any(named: 'deviceTime'),
            timeOffsetSeconds: any(named: 'timeOffsetSeconds'),
          ));
      verifyNever(() => mockStorage.setTimeTampered(any()));
      verifyNever(() => mockStorage.saveActivationVerified(any()));
    });

    test(
        'returns false and has no side-effects when guard reports no tampering',
        () async {
      final trustedTime =
          DateTime.now().toUtc().subtract(const Duration(hours: 1));
      when(() => mockStorage.getLastTrustedTime())
          .thenAnswer((_) async => trustedTime);
      when(() => mockStorage.getTimeOffset()).thenAnswer((_) async => 0);
      when(() => mockTamperGuard.isTampered(
            lastTrustedTime: any(named: 'lastTrustedTime'),
            deviceTime: any(named: 'deviceTime'),
            timeOffsetSeconds: any(named: 'timeOffsetSeconds'),
          )).thenReturn(false);

      expect(await service.checkTimeTampering(), isFalse);

      verifyNever(() => mockStorage.setTimeTampered(any()));
      verifyNever(() => mockStorage.saveActivationVerified(any()));
    });

    test(
        'returns true and triggers storage side-effects '
        'when guard detects clock rollback', () async {
      final trustedTime =
          DateTime.now().toUtc().subtract(const Duration(hours: 1));
      when(() => mockStorage.getLastTrustedTime())
          .thenAnswer((_) async => trustedTime);
      when(() => mockStorage.getTimeOffset()).thenAnswer((_) async => 0);
      when(() => mockTamperGuard.isTampered(
            lastTrustedTime: any(named: 'lastTrustedTime'),
            deviceTime: any(named: 'deviceTime'),
            timeOffsetSeconds: any(named: 'timeOffsetSeconds'),
          )).thenReturn(true);
      when(() => mockStorage.setTimeTampered(true)).thenAnswer((_) async {});
      when(() => mockStorage.saveActivationVerified(false))
          .thenAnswer((_) async {});

      expect(await service.checkTimeTampering(), isTrue);

      verify(() => mockStorage.setTimeTampered(true)).called(1);
      verify(() => mockStorage.saveActivationVerified(false)).called(1);
    });

    test('passes the stored time-offset to the guard', () async {
      final trustedTime = DateTime.now().toUtc();
      when(() => mockStorage.getLastTrustedTime())
          .thenAnswer((_) async => trustedTime);
      when(() => mockStorage.getTimeOffset()).thenAnswer((_) async => 120);
      when(() => mockTamperGuard.isTampered(
            lastTrustedTime: any(named: 'lastTrustedTime'),
            deviceTime: any(named: 'deviceTime'),
            timeOffsetSeconds: any(named: 'timeOffsetSeconds'),
          )).thenReturn(false);

      await service.checkTimeTampering();

      final captured = verify(() => mockTamperGuard.isTampered(
            lastTrustedTime: any(named: 'lastTrustedTime'),
            deviceTime: any(named: 'deviceTime'),
            timeOffsetSeconds: captureAny(named: 'timeOffsetSeconds'),
          )).captured;

      expect(captured.first, equals(120));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // isOfflineLimitExceeded — delegates arithmetic to OfflineLimitGuard,
  // updates the persisted exceeded flag as a side-effect
  // ════════════════════════════════════════════════════════════════════════════

  group('isOfflineLimitExceeded', () {
    test('returns false immediately when no sync has been recorded', () async {
      when(() => mockStorage.getLastOnlineSync()).thenAnswer((_) async => null);

      expect(await service.isOfflineLimitExceeded(), isFalse);

      verifyNever(() => mockOfflineGuard.hasExceeded(any()));
    });

    test(
        'returns true and persists exceeded=true when guard says limit is '
        'exceeded', () async {
      final lastSync =
          DateTime.now().toUtc().subtract(const Duration(hours: 100));
      when(() => mockStorage.getLastOnlineSync())
          .thenAnswer((_) async => lastSync);
      when(() => mockOfflineGuard.hasExceeded(any())).thenReturn(true);
      when(() => mockStorage.setOfflineLimitExceeded(true))
          .thenAnswer((_) async {});

      expect(await service.isOfflineLimitExceeded(), isTrue);

      verify(() => mockStorage.setOfflineLimitExceeded(true)).called(1);
    });

    test(
        'clears the exceeded flag and returns false when the device has '
        'come back online within the window (shouldClearExceededFlag=true)',
        () async {
      final lastSync =
          DateTime.now().toUtc().subtract(const Duration(hours: 24));
      when(() => mockStorage.getLastOnlineSync())
          .thenAnswer((_) async => lastSync);
      when(() => mockOfflineGuard.hasExceeded(any())).thenReturn(false);
      when(() => mockStorage.hasOfflineLimitExceeded())
          .thenAnswer((_) async => true);
      when(() => mockOfflineGuard.shouldClearExceededFlag(any(), any()))
          .thenReturn(true);
      when(() => mockStorage.setOfflineLimitExceeded(false))
          .thenAnswer((_) async {});

      expect(await service.isOfflineLimitExceeded(), isFalse);

      verify(() => mockStorage.setOfflineLimitExceeded(false)).called(1);
    });

    test(
        'returns the cached exceeded flag (true) when guard says neither '
        'exceeded nor should-clear', () async {
      final lastSync =
          DateTime.now().toUtc().subtract(const Duration(hours: 50));
      when(() => mockStorage.getLastOnlineSync())
          .thenAnswer((_) async => lastSync);
      when(() => mockOfflineGuard.hasExceeded(any())).thenReturn(false);
      when(() => mockStorage.hasOfflineLimitExceeded())
          .thenAnswer((_) async => true);
      when(() => mockOfflineGuard.shouldClearExceededFlag(any(), any()))
          .thenReturn(false);

      expect(await service.isOfflineLimitExceeded(), isTrue);
    });

    test('returns false when previously not exceeded and still within limit',
        () async {
      final lastSync =
          DateTime.now().toUtc().subtract(const Duration(hours: 10));
      when(() => mockStorage.getLastOnlineSync())
          .thenAnswer((_) async => lastSync);
      when(() => mockOfflineGuard.hasExceeded(any())).thenReturn(false);
      when(() => mockStorage.hasOfflineLimitExceeded())
          .thenAnswer((_) async => false);
      when(() => mockOfflineGuard.shouldClearExceededFlag(any(), any()))
          .thenReturn(false);

      expect(await service.isOfflineLimitExceeded(), isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // hasAgentData — checks that both name and phone fields are non-empty
  // ════════════════════════════════════════════════════════════════════════════

  group('hasAgentData', () {
    test('returns true when both name and phone are present', () async {
      when(() => mockStorage.getAgentName()).thenAnswer((_) async => 'Ahmed');
      when(() => mockStorage.getAgentPhone())
          .thenAnswer((_) async => '0501234567');

      expect(await service.hasAgentData(), isTrue);
    });

    test('returns false when agent name is empty', () async {
      when(() => mockStorage.getAgentName()).thenAnswer((_) async => '');
      when(() => mockStorage.getAgentPhone())
          .thenAnswer((_) async => '0501234567');

      expect(await service.hasAgentData(), isFalse);
    });

    test('returns false when agent phone is empty', () async {
      when(() => mockStorage.getAgentName()).thenAnswer((_) async => 'Ahmed');
      when(() => mockStorage.getAgentPhone()).thenAnswer((_) async => '');

      expect(await service.hasAgentData(), isFalse);
    });

    test('returns false when both name and phone are empty', () async {
      when(() => mockStorage.getAgentName()).thenAnswer((_) async => '');
      when(() => mockStorage.getAgentPhone()).thenAnswer((_) async => '');

      expect(await service.hasAgentData(), isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // sendActivationRequest — orchestrates API call, persists server response,
  // and conditionally disables trial mode
  // ════════════════════════════════════════════════════════════════════════════

  group('sendActivationRequest', () {
    /// Sets up the API mock to return [data] for any createDevice call.
    void stubApiCreate(Map<String, dynamic> data) {
      when(() => mockApi.createDevice(
            deviceId: any(named: 'deviceId'),
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
          )).thenAnswer((_) async => data);
    }

    test(
        'returns true, persists all server data, and disables trial mode '
        'when is_verified=1 with expires_at and plan', () async {
      stubApiCreate({
        'is_verified': 1,
        'server_time': '2026-04-12T10:00:00Z',
        'expires_at': '2027-04-12T00:00:00Z',
        'plan': 'yearly',
      });
      when(() => mockStorage.saveTrustedTimeAndOffset(any()))
          .thenAnswer((_) async {});
      when(() => mockStorage.updateLastOnlineSync()).thenAnswer((_) async {});
      when(() => mockStorage.saveActivationVerified(true))
          .thenAnswer((_) async {});
      when(() => mockStorage.saveExpiresAt(any())).thenAnswer((_) async {});
      when(() => mockTrialService.disableTrialMode()).thenAnswer((_) async {});
      when(() => mockStorage.saveSelectedPlan(any())).thenAnswer((_) async {});
      when(() => mockStorage.setActivationCalled()).thenAnswer((_) async {});

      final result =
          await service.sendActivationRequest('Ahmed', '0501234567', 'dev1');

      expect(result, isTrue);
      verify(() => mockStorage.saveTrustedTimeAndOffset('2026-04-12T10:00:00Z'))
          .called(1);
      verify(() => mockStorage.updateLastOnlineSync()).called(1);
      verify(() => mockStorage.saveActivationVerified(true)).called(1);
      verify(() => mockStorage.saveExpiresAt('2027-04-12T00:00:00Z')).called(1);
      verify(() => mockTrialService.disableTrialMode()).called(1);
      verify(() => mockStorage.saveSelectedPlan('yearly')).called(1);
      verify(() => mockStorage.setActivationCalled()).called(1);
    });

    test(
        'returns true and still disables trial mode when verified '
        'but expires_at is absent (legacy activation)', () async {
      stubApiCreate({
        'is_verified': 1,
        'server_time': null,
        'expires_at': null,
        'plan': null,
      });
      when(() => mockStorage.updateLastOnlineSync()).thenAnswer((_) async {});
      when(() => mockStorage.saveActivationVerified(true))
          .thenAnswer((_) async {});
      when(() => mockTrialService.disableTrialMode()).thenAnswer((_) async {});
      when(() => mockStorage.setActivationCalled()).thenAnswer((_) async {});

      final result =
          await service.sendActivationRequest('Ahmed', '0501234567', 'dev1');

      expect(result, isTrue);
      verify(() => mockTrialService.disableTrialMode()).called(1);
      // expires_at was null, so saveExpiresAt must NOT be called.
      verifyNever(() => mockStorage.saveExpiresAt(any()));
    });

    test(
        'returns false and does NOT disable trial mode when '
        'is_verified=0', () async {
      stubApiCreate({
        'is_verified': 0,
        'server_time': null,
        'expires_at': null,
        'plan': null,
      });
      when(() => mockStorage.updateLastOnlineSync()).thenAnswer((_) async {});
      when(() => mockStorage.saveActivationVerified(false))
          .thenAnswer((_) async {});
      when(() => mockStorage.setActivationCalled()).thenAnswer((_) async {});

      final result =
          await service.sendActivationRequest('Ahmed', '0501234567', 'dev1');

      expect(result, isFalse);
      verifyNever(() => mockTrialService.disableTrialMode());
      verify(() => mockStorage.saveActivationVerified(false)).called(1);
    });

    test(
        'does not call saveTrustedTimeAndOffset when server_time is absent',
        () async {
      stubApiCreate({
        'is_verified': 1,
        'server_time': null,
        'expires_at': null,
        'plan': null,
      });
      when(() => mockStorage.updateLastOnlineSync()).thenAnswer((_) async {});
      when(() => mockStorage.saveActivationVerified(true))
          .thenAnswer((_) async {});
      when(() => mockTrialService.disableTrialMode()).thenAnswer((_) async {});
      when(() => mockStorage.setActivationCalled()).thenAnswer((_) async {});

      await service.sendActivationRequest('Ahmed', '0501234567', 'dev1');

      verifyNever(() => mockStorage.saveTrustedTimeAndOffset(any()));
    });

    test(
        'throws Exception with Arabic error message when the API throws',
        () async {
      when(() => mockApi.createDevice(
            deviceId: any(named: 'deviceId'),
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
          )).thenThrow(Exception('Network error'));

      await expectLater(
        service.sendActivationRequest('Ahmed', '0501234567', 'dev1'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'contains Arabic failure message',
            contains('فشل الاتصال'),
          ),
        ),
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // checkDeviceStatus — orchestrates device status sync with the server
  // ════════════════════════════════════════════════════════════════════════════

  group('checkDeviceStatus', () {
    test('returns false immediately when agent name is empty', () async {
      when(() => mockDeviceIdentity.getDeviceId())
          .thenAnswer((_) async => 'dev1');
      when(() => mockStorage.getAgentName()).thenAnswer((_) async => '');
      when(() => mockStorage.getAgentPhone())
          .thenAnswer((_) async => '0501234567');

      expect(await service.checkDeviceStatus(), isFalse);
      verifyNever(
          () => mockApi.checkDevice(deviceId: any(named: 'deviceId')));
    });

    test('returns false immediately when agent phone is empty', () async {
      when(() => mockDeviceIdentity.getDeviceId())
          .thenAnswer((_) async => 'dev1');
      when(() => mockStorage.getAgentName())
          .thenAnswer((_) async => 'Ahmed');
      when(() => mockStorage.getAgentPhone()).thenAnswer((_) async => '');

      expect(await service.checkDeviceStatus(), isFalse);
      verifyNever(
          () => mockApi.checkDevice(deviceId: any(named: 'deviceId')));
    });

    test('returns false when API returns null (non-200 response)', () async {
      stubCheckDevice(verified: false); // provides agent data + API null path
      // Override the checkDevice stub to return null.
      when(() => mockApi.checkDevice(deviceId: any(named: 'deviceId')))
          .thenAnswer((_) async => null);

      expect(await service.checkDeviceStatus(), isFalse);
    });

    test(
        'returns true, persists server data, and updates online sync '
        'when is_verified=1', () async {
      stubCheckDevice(
        verified: true,
        serverTime: '2026-04-12T10:00:00Z',
        expiresAt: '2027-04-12T00:00:00Z',
        plan: 'yearly',
      );

      expect(await service.checkDeviceStatus(), isTrue);
      verify(() => mockStorage.saveActivationVerified(true)).called(1);
      verify(() => mockStorage.updateLastOnlineSync()).called(1);
      verify(() => mockStorage.saveExpiresAt('2027-04-12T00:00:00Z')).called(1);
      verify(() => mockStorage.saveSelectedPlan('yearly')).called(1);
      verify(() => mockStorage.saveTrustedTimeAndOffset(
          '2026-04-12T10:00:00Z')).called(1);
    });

    test(
        'returns false and persists verified=false '
        'when is_verified=0', () async {
      stubCheckDevice(verified: false);

      expect(await service.checkDeviceStatus(), isFalse);
      verify(() => mockStorage.saveActivationVerified(false)).called(1);
      verify(() => mockStorage.updateLastOnlineSync()).called(1);
    });

    test('does not persist server_time when it is absent', () async {
      stubCheckDevice(verified: true); // serverTime is null by default

      await service.checkDeviceStatus();

      verifyNever(() => mockStorage.saveTrustedTimeAndOffset(any()));
    });

    test('does not persist expires_at when it is absent', () async {
      stubCheckDevice(verified: true); // expiresAt is null by default

      await service.checkDeviceStatus();

      verifyNever(() => mockStorage.saveExpiresAt(any()));
    });

    test('rethrows exceptions propagated from the API layer', () async {
      when(() => mockDeviceIdentity.getDeviceId())
          .thenAnswer((_) async => 'dev1');
      when(() => mockStorage.getAgentName())
          .thenAnswer((_) async => 'Ahmed');
      when(() => mockStorage.getAgentPhone())
          .thenAnswer((_) async => '0501234567');
      when(() => mockApi.checkDevice(deviceId: any(named: 'deviceId')))
          .thenThrow(Exception('Connection timeout'));

      await expectLater(
        service.checkDeviceStatus(),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // recheckActivationStatus — compound orchestration:
  // checkDeviceStatus → saveActivationStatus → [disableTrialMode] → isActivated
  // ════════════════════════════════════════════════════════════════════════════

  group('recheckActivationStatus', () {
    test(
        'disables trial mode, persists status, and returns true '
        'when server verifies the device', () async {
      stubCheckDevice(verified: true);
      when(() => mockStorage.saveActivationStatus(true))
          .thenAnswer((_) async {});
      when(() => mockTrialService.disableTrialMode()).thenAnswer((_) async {});
      stubIsActivated(activated: true);

      expect(await service.recheckActivationStatus(), isTrue);

      verify(() => mockStorage.saveActivationStatus(true)).called(1);
      verify(() => mockTrialService.disableTrialMode()).called(1);
    });

    test(
        'does NOT disable trial mode, persists status=false, and returns false '
        'when server reports device as unverified', () async {
      stubCheckDevice(verified: false);
      when(() => mockStorage.saveActivationStatus(false))
          .thenAnswer((_) async {});
      stubIsActivated(activated: false);

      expect(await service.recheckActivationStatus(), isFalse);

      verify(() => mockStorage.saveActivationStatus(false)).called(1);
      verifyNever(() => mockTrialService.disableTrialMode());
    });

    test(
        'returns false via isActivated() when tampered even though server '
        'returned verified=true', () async {
      stubCheckDevice(verified: true);
      when(() => mockStorage.saveActivationStatus(true))
          .thenAnswer((_) async {});
      when(() => mockTrialService.disableTrialMode()).thenAnswer((_) async {});

      // isActivated() detects tampering → false.
      when(() => mockStorage.isTimeTampered()).thenAnswer((_) async => true);

      expect(await service.recheckActivationStatus(), isFalse);
    });

    test(
        'returns false via isActivated() when license expired even though '
        'server returned verified=true', () async {
      stubCheckDevice(verified: true);
      when(() => mockStorage.saveActivationStatus(true))
          .thenAnswer((_) async {});
      when(() => mockTrialService.disableTrialMode()).thenAnswer((_) async {});

      when(() => mockStorage.isTimeTampered()).thenAnswer((_) async => false);
      when(() => mockStorage.readActivationStatus())
          .thenAnswer((_) async => true);
      when(() => mockStorage.getExpiresAt())
          .thenAnswer((_) async => '2020-01-01T00:00:00Z'); // expired
      when(() => mockStorage.saveActivationVerified(false))
          .thenAnswer((_) async {});

      expect(await service.recheckActivationStatus(), isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // updateMyData — delegates to API, propagating success/failure/errors
  // ════════════════════════════════════════════════════════════════════════════

  group('updateMyData', () {
    test('returns true when API acknowledges the update', () async {
      when(() => mockDeviceIdentity.getDeviceId())
          .thenAnswer((_) async => 'dev1');
      when(() => mockApi.updateMyData(
            deviceId: any(named: 'deviceId'),
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
          )).thenAnswer((_) async => true);

      expect(await service.updateMyData('Ahmed', '0501234567'), isTrue);
    });

    test('passes device ID, name and phone to the API correctly', () async {
      when(() => mockDeviceIdentity.getDeviceId())
          .thenAnswer((_) async => 'device-abc');
      when(() => mockApi.updateMyData(
            deviceId: any(named: 'deviceId'),
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
          )).thenAnswer((_) async => true);

      await service.updateMyData('Sara', '0559876543');

      verify(() => mockApi.updateMyData(
            deviceId: 'device-abc',
            fullName: 'Sara',
            phone: '0559876543',
          )).called(1);
    });

    test('returns false when API returns false', () async {
      when(() => mockDeviceIdentity.getDeviceId())
          .thenAnswer((_) async => 'dev1');
      when(() => mockApi.updateMyData(
            deviceId: any(named: 'deviceId'),
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
          )).thenAnswer((_) async => false);

      expect(await service.updateMyData('Ahmed', '0501234567'), isFalse);
    });

    test('rethrows exception from the API layer', () async {
      when(() => mockDeviceIdentity.getDeviceId())
          .thenAnswer((_) async => 'dev1');
      when(() => mockApi.updateMyData(
            deviceId: any(named: 'deviceId'),
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
          )).thenThrow(Exception('Timeout'));

      await expectLater(
        service.updateMyData('Ahmed', '0501234567'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Trial-mode facade delegation — ActivationService passes through to
  // TrialModeService without adding logic
  // ════════════════════════════════════════════════════════════════════════════

  group('trial-mode facade delegation', () {
    test('disableTrialMode() delegates to TrialModeService', () async {
      when(() => mockTrialService.disableTrialMode()).thenAnswer((_) async {});

      await service.disableTrialMode();

      verify(() => mockTrialService.disableTrialMode()).called(1);
    });

    test('enableTrialMode() delegates to TrialModeService', () async {
      when(() => mockTrialService.enableTrialMode()).thenAnswer((_) async {});

      await service.enableTrialMode();

      verify(() => mockTrialService.enableTrialMode()).called(1);
    });

    test('isTrialMode() delegates to TrialModeService', () async {
      when(() => mockTrialService.isTrialMode()).thenAnswer((_) async => true);

      expect(await service.isTrialMode(), isTrue);
    });

    test('hasTrialExpired() delegates to TrialModeService', () async {
      when(() => mockTrialService.hasTrialExpired())
          .thenAnswer((_) async => true);

      expect(await service.hasTrialExpired(), isTrue);
    });

    test('hasTrialBeenUsedOnce() returns value from TrialModeService',
        () async {
      when(() => mockTrialService.hasTrialBeenUsedOnce())
          .thenAnswer((_) async => false);

      expect(await service.hasTrialBeenUsedOnce(), isFalse);
    });
  });
}

