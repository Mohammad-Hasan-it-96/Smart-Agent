import 'package:get_it/get_it.dart';
import '../db/database_helper.dart';
import '../services/activation_local_storage.dart';
import '../services/activation_service.dart';
import '../services/backup_service.dart';
import '../services/bluetooth_print_service.dart';
import '../services/device_api_repository.dart';
import '../services/device_identity_service.dart';
import '../services/offline_limit_guard.dart';
import '../services/settings_service.dart';
import '../services/time_tamper_guard.dart';
import '../services/trial_mode_service.dart';
import '../services/update_service.dart';

/// Global [GetIt] instance — import this wherever a service is needed.
final GetIt getIt = GetIt.instance;

/// Registers all core services.
///
/// Call once from [main] before [runApp].
/// All services are registered as lazy singletons so they are created
/// on first access rather than eagerly at startup.
Future<void> setupServiceLocator() async {
  // ── Pure-logic guards (stateless, no I/O) ────────────────────────────
  getIt.registerLazySingleton<TimeTamperGuard>(() => TimeTamperGuard());
  getIt.registerLazySingleton<OfflineLimitGuard>(() => OfflineLimitGuard());

  // ── Persistence layer ─────────────────────────────────────────────────
  getIt.registerLazySingleton<ActivationLocalStorage>(
      () => ActivationLocalStorage());

  // ── Domain services ───────────────────────────────────────────────────
  getIt.registerLazySingleton<DeviceIdentityService>(
      () => DeviceIdentityService());
  getIt.registerLazySingleton<DeviceApiRepository>(() => DeviceApiRepository());
  getIt.registerLazySingleton<TrialModeService>(() => TrialModeService(
        localStorage: getIt<ActivationLocalStorage>(),
        db: getIt<DatabaseHelper>(),
      ));
  getIt.registerLazySingleton<ActivationService>(() => ActivationService(
        localStorage: getIt<ActivationLocalStorage>(),
        deviceIdentity: getIt<DeviceIdentityService>(),
        api: getIt<DeviceApiRepository>(),
        tamperGuard: getIt<TimeTamperGuard>(),
        offlineGuard: getIt<OfflineLimitGuard>(),
        trialService: getIt<TrialModeService>(),
      ));
  getIt.registerLazySingleton<SettingsService>(() => SettingsService());
  getIt.registerLazySingleton<UpdateService>(() => UpdateService());
  getIt.registerLazySingleton<BackupService>(() => BackupService());

  // ── Sprint 5 — Bluetooth printing ─────────────────────────────────────
  getIt.registerLazySingleton<BluetoothPrintService>(
      () => BluetoothPrintService());

  // ── Database ──────────────────────────────────────────────────────────
  // DatabaseHelper uses its own singleton pattern; we expose the existing
  // instance via DI so future code can resolve it without knowing the
  // static accessor.
  getIt.registerSingleton<DatabaseHelper>(DatabaseHelper.instance);
}

