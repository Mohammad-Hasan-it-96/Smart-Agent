# 🔍 Technical Audit Report — Smart Agent (المندوب الذكي)

> **Audit Date:** April 12, 2026
> **Auditor:** Automated Codebase Analysis
> **Scope:** Full Flutter project — `lib/` directory, `pubspec.yaml`, Android manifest
> **Purpose:** Pre-refactoring readiness assessment

---

## 1. Executive Summary

The **Smart Agent** codebase is a functional, well-featured Flutter app with a clearly defined domain (pharmaceutical field sales). The UI layer is polished and the core activation/security logic is well-thought-out. However, the architecture has several systemic weaknesses that will slow down future development, make testing impossible, and create maintenance debt as the project scales.

### Critical Verdict

| Area | Rating | Notes |
|---|---|---|
| Feature Completeness | ✅ Good | All major features implemented and working |
| UI Quality | ✅ Good | Glassmorphism design, RTL, Dark Mode |
| Security Logic | ✅ Good | SHA256 device ID, time tamper detection, offline limit |
| Architecture | ⚠️ Weak | No DI, no repository pattern, god-class service |
| Error Handling | ❌ Poor | 11 swallowed exceptions, 13 raw `print()` calls |
| Testability | ❌ Zero | No tests, no interfaces, no mocks possible |
| Config Security | ⚠️ Partial | Hardcoded URLs/tokens in source code |
| Constants Management | ⚠️ Weak | Magic strings for SharedPreferences keys |

### Top 3 Most Urgent Issues
1. **`ActivationService` is a 897-line god-class** — must be split before adding any feature
2. **13 `print()` statements leak sensitive data in production builds** — some in production hot paths
3. **`ActivationService()` is `new`-ed 20 times across the app** — untestable and wasteful

---

## 2. Project Structure Overview

```
lib/
├── main.dart                          ← Bootstrap + route table (176 lines)
├── core/
│   ├── db/database_helper.dart        ← SQLite v11, singleton, 514 lines
│   ├── models/                        ← 8 plain Dart model classes ✅
│   ├── providers/theme_provider.dart  ← Only ChangeNotifier provider
│   ├── services/                      ← 13 services (see audit below)
│   ├── theme/app_theme.dart           ← Centralized theme ✅
│   ├── utils/                         ← 3 utility files ✅
│   └── widgets/                       ← 5 shared widgets ✅
├── features/
│   ├── activation/                    ← 7 screens
│   ├── companies/                     ← 2 files
│   ├── home/                          ← screen + controller
│   ├── medicines/                     ← 2 files
│   ├── onboarding/                    ← 1 file
│   ├── orders/                        ← 5 files (largest feature)
│   ├── pharmacies/                    ← 2 files
│   ├── search/                        ← 1 file (866 lines, uses debouncing ✅)
│   ├── settings/                      ← screen + controller + widget
│   └── splash/                        ← 1 file (378 lines, complex animation)
└── widgets/                           ← ⚠️ EMPTY FOLDER — dead code
```

### Structural Observations
- ✅ Feature-based folder structure is correct and scalable
- ✅ Models are clean plain Dart objects with `toMap`/`fromMap`
- ✅ `core/` separation is good in concept
- ⚠️ `lib/widgets/` folder exists but is **completely empty** — should be deleted
- ⚠️ Controllers exist only for `home` and `settings` — other screens manage state inline
- ❌ No `repositories/` layer — DB access goes directly from screens into `DatabaseHelper`
- ❌ No `interfaces/` or `abstractions/` — makes mocking impossible

---

## 3. Critical Services Audit

### 3.1 `ActivationService` — ⭐ Highest Priority Refactor Target

**File:** `lib/core/services/activation_service.dart`
**Size:** 897 lines

**Responsibilities (too many — violates Single Responsibility Principle):**

| Responsibility | Should belong to |
|---|---|
| HTTP: create/check device | `DeviceApiRepository` |
| HTTP: update user data | `DeviceApiRepository` |
| HTTP: send subscription request | `SubscriptionRepository` |
| Device ID generation (SHA256) | `DeviceIdentityService` |
| `SharedPreferences` read/write for activation | `ActivationLocalStorage` |
| `SharedPreferences` read/write for trial | `TrialLocalStorage` |
| File-based expiry persistence | `ActivationLocalStorage` |
| Time tamper detection logic | `TimeTamperGuard` |
| Offline-limit calculation | `OfflineLimitGuard` |
| Trial mode lifecycle | `TrialModeService` |
| Trial limits (DB queries) | `TrialLimitChecker` |
| Agent name/phone storage | `AgentProfileStorage` |

**Problems:**
- `SharedPreferences.getInstance()` is called **30+ times inside this one service** — every method creates a new call instead of caching the instance
- Contains **8 nested constant string keys** duplicated between itself and `SettingsController` (`hide_home_carousel`, `enable_gifts` are managed separately)
- `_trialActiveKey`, `_trialEnabledKey` etc. are private but conceptually belong to a separate trial service

---

### 3.2 `SettingsService` — Acceptable but Has Issues

**File:** `lib/core/services/settings_service.dart`
**Size:** 178 lines

- ✅ Static methods for global access are reasonable for config
- ⚠️ Contains hardcoded personal contact data (see Config Audit §5)
- ⚠️ `getApiBaseUrl()` and `buildApiUri()` are `async` but called many times — each call does a `SharedPreferences.getInstance()` which is wasteful

---

### 3.3 `BackupService` — Needs Cleanup

**File:** `lib/core/services/backup_service.dart`
**Size:** 244 lines

- ⚠️ 5 raw `print()` calls including `print('Backup error: $e')` and `print('Restore error: $e')` — these run in production
- ⚠️ Never instantiated via DI — not registered anywhere, created on demand in `settings_screen.dart` implicitly through the screen's own logic
- ❌ No progress reporting during upload/download (user sees nothing during long operations)
- ❌ `.old` backup file is never cleaned up

---

### 3.4 `PushNotificationService` — Mostly Good

**File:** `lib/core/services/push_notification_service.dart`
**Size:** 375 lines

- ✅ Proper singleton pattern
- ✅ Handles foreground/background/launch correctly
- ✅ Debounces activation refresh to avoid multiple dialogs
- ⚠️ Creates `ActivationService()` directly: `final ActivationService _activationService = ActivationService();`
- ⚠️ Creates `NotificationApiService()` directly: `final NotificationApiService _apiService = NotificationApiService();`
- ⚠️ `catch (_) {}` on line 19 (Firebase init failure swallowed silently)

---

### 3.5 `UpdateService` — Acceptable

**File:** `lib/core/services/update_service.dart`
**Size:** 198 lines

- ✅ ABI detection is a nice feature
- ✅ HTML-response detection guard is good defensive coding
- ⚠️ Hardcoded Google Drive URL with a file ID (see Config Audit §5)
- ⚠️ `_debugLog` uses `print()` inside `assert()` — only runs in debug mode, acceptable
- ⚠️ `UpdateService()` created at call site in both `HomeScreen` and `SettingsScreen` independently

---

### 3.6 `DatabaseHelper` — Mostly Solid

**File:** `lib/core/db/database_helper.dart`
**Size:** 514 lines

- ✅ Proper singleton with lazy init
- ✅ Migrations are sequential and well-guarded with try/catch
- ✅ Search helpers moved here (good — keeps SQL centralized)
- ⚠️ `static DatabaseHelper _instance` is a mutable static — `resetInstance()` exists but is only called from `BackupService`; concurrent access is not guarded
- ⚠️ All screens access `DatabaseHelper.instance` directly — no repository abstraction
- ❌ `DatabaseHelper` is not mockable — makes unit testing impossible

---

### 3.7 `NotificationActionHandler` — Design Issue

**File:** `lib/core/services/notification_action_handler.dart`
**Size:** 134 lines

- ❌ Creates `ActivationService()` twice inside a static method (lines 15, 55) — each invocation creates a new instance
- ❌ These are throw-away instances that are garbage collected after each call
- ⚠️ Mixing UI code (dialogs, navigation) with business logic in the same static class

---

## 4. UI / Screens Audit

### 4.1 Screen-Level Issues Summary

| Screen | Service instantiation | DB access | Issues |
|---|---|---|---|
| `SplashScreen` | `ActivationService()` ✗ | — | `catch (_) {}` swallows errors |
| `HomeScreen` | `UpdateService()` ✗ | — | `catch (_) {}` swallows update check |
| `HomeController` | `ActivationService()` ✗ | `DatabaseHelper.instance` ✗ | 3× empty catch |
| `ActivationScreen` | `ActivationService()` ✗ | — | `FutureBuilder` inside `build()` |
| `AgentRegistrationScreen` | `ActivationService()` ✗ | — | Mixes local save + network |
| `OnboardingScreen` | `ActivationService()` ✗ | — | Direct prefs access |
| `OfflineLimitScreen` | `ActivationService()` ✗ | — | ✅ Double-tap guard is correct |
| `SettingsScreen` | `DataExportService()` ✗, `ContactLauncherService()` ✗, `UpdateService()` ✗ | — | 4+ catch blocks |
| `SettingsController` | `ActivationService()` ✗, `SettingsService()` ✗ | — | 2× empty catch, raw string keys |
| `NewOrderScreen` | `ActivationService()` ✗×2, `SettingsService()` ✗ | `DatabaseHelper.instance` ✗ | `print()` in build path |
| `OrdersListScreen` | — | `DatabaseHelper.instance` ✗ | 3× debug `print()` ← **critical** |
| `OrderDetailsScreen` | `ActivationService()` ✗, `SettingsService()` ✗ | `DatabaseHelper.instance` ✗ | 4× catch blocks |
| `MedicinesScreen` | `ActivationService()` ✗, `SettingsService()` ✗ | `DatabaseHelper.instance` ✗ | |
| `MedicineForm` | `ActivationService()` ✗, `SettingsService()` ✗ | `DatabaseHelper.instance` ✗ | |
| `CompaniesScreen` | `ActivationService()` ✗ | `DatabaseHelper.instance` ✗ | |
| `CompanyForm` | `ActivationService()` ✗ | `DatabaseHelper.instance` ✗ | |
| `PharmaciesScreen` | `ActivationService()` ✗ | `DatabaseHelper.instance` ✗ | |
| `PharmacyForm` | `ActivationService()` ✗ | `DatabaseHelper.instance` ✗ | |
| `SearchScreen` | — | `DatabaseHelper.instance` ✗ | ✅ Has debouncing |
| `PdfExporter` | `ActivationService()` ✗, `SettingsService()` ✗ | `DatabaseHelper.instance` ✗ | 3× `print()` |

**Legend:** ✗ = direct instantiation (DI violation)

---

### 4.2 Notable Design Issue — `FutureBuilder` Inside `build()`

In `ActivationScreen`, a `FutureBuilder<bool>` is called inside `_buildNotActivatedView()`:

```dart
// activation_screen.dart ~line 350
FutureBuilder<bool>(
  future: _activationService.hasTrialBeenUsedOnce(),  // ← called on every rebuild!
  builder: (context, snapshot) { ... },
),
```

This creates a new `Future` on every `setState()` rebuild, causing network/IO re-calls unnecessarily. Should be cached in `initState`.

---

### 4.3 Notable Design Issue — Debug Print in Hot Path

In `OrdersListScreen._loadOrdersByDay()` (lines 53–56):

```dart
// This runs EVERY TIME the orders list is opened in production
print('Sample orders in database:');
for (var row in allOrders) {
  print('  Order ID: ${row['id']}, Date part: ...');
}
```

This performs a **debug SQL query with no purpose in production** and prints each row. Must be removed.

Similarly in `NewOrderScreen`:
```dart
print("Selected: ${medicine.name}");  // line 388 — runs every medicine selection
```

---

## 5. Config / Security Audit

### 5.1 Hardcoded Values Inventory

| Value | File | Line | Risk Level |
|---|---|---|---|
| API Base URL `harrypotter.foodsalebot.com` | `settings_service.dart` | 5 | 🔴 High — exposes server domain |
| Support Email `mohamad.hasan.it.96@gmail.com` | `settings_service.dart` | 6 | 🟡 Medium — personal email in source |
| Support Telegram `+963983820430` | `settings_service.dart` | 7 | 🟡 Medium — personal phone in source |
| Support WhatsApp `963983820430` | `settings_service.dart` | 8 | 🟡 Medium — personal phone in source |
| Update Config Google Drive ID `1aMv_VNEFff1XzQeiG80s0aEL4r5_c9ao` | `update_service.dart` | 35 | 🟡 Medium — Drive file ID exposed |
| App name salt `smart_agent_app` | `activation_service.dart` | 54 | 🟡 Medium — hashing salt in source |
| App name string `'SmartAgent'` | `activation_service.dart` | 76, 393, 478, 799 + 2 others | 🟡 Medium — magic string, 7 occurrences |

### 5.2 Magic String Keys (SharedPreferences)

The following keys are used as raw strings with no central constants file:

| Key String | Used In | Has Constant? |
|---|---|---|
| `'pdf_font_size'` | `SettingsController` only | ❌ No |
| `'enable_gifts'` | `SettingsController` only | ❌ No |
| `'hide_home_carousel'` | `HomeController` (has const) + `SettingsController` (raw string) | ⚠️ Partial |
| `'onboarding_completed'` | `SplashScreen` + `OnboardingScreen` | ❌ No |

**Risk:** A typo in any of these strings would cause a silent bug. There is no single source of truth for all preference keys.

### 5.3 App Name Used as API Parameter (7 places)

The string `'SmartAgent'` is sent to the backend API as `app_name` in every HTTP request:
```dart
'app_name': 'SmartAgent',  // appears 4× in activation_service.dart alone
```
This should be a single constant defined once, e.g. `AppConstants.appName`.

---

## 6. Logging / Error-Handling Audit

### 6.1 `print()` Usage — All 13 Occurrences

| File | Line(s) | Content | Severity |
|---|---|---|---|
| `orders_list_screen.dart` | 53–56 | Debug DB query + row dump | 🔴 CRITICAL — runs in production on every open |
| `orders_list_screen.dart` | 84 | `'Error loading orders by day: $e'` | 🟡 Acceptable but should use logger |
| `new_order_screen.dart` | 388 | `"Selected: ${medicine.name}"` | 🔴 Runs on every medicine tap in production |
| `pdf_exporter.dart` | 23 | DB fetch warning | 🟡 Should use logger |
| `pdf_exporter.dart` | 34–35 | Font not found warning | 🟡 Should use logger |
| `backup_service.dart` | 31 | Google Sign-In error | 🟡 Prints in production |
| `backup_service.dart` | 50 | Sign-Out error | 🟡 Prints in production |
| `backup_service.dart` | 114 | No existing backup | 🟢 Low severity |
| `backup_service.dart` | 131 | Backup error | 🟡 Prints error object |
| `backup_service.dart` | 203 | Restore error | 🟡 Prints error object |
| `update_service.dart` | 118 | Inside `assert()` — debug only | ✅ Safe |

### 6.2 Empty / Swallowed `catch` Blocks — All 11 Occurrences

| File | Location | Impact |
|---|---|---|
| `home_controller.dart:66` | Inside `load()` — wraps entire activation + stats load | 🔴 Silently fails on startup |
| `home_controller.dart:78` | Inside `refreshStats()` | 🟡 Stats never refresh if DB fails |
| `home_controller.dart:140` | Inside `checkExpiration()` | 🟡 Expiration check silently fails |
| `splash_screen.dart:160` | `checkDeviceStatus()` network call | 🟢 Intentional — offline fallback |
| `splash_screen.dart:365` | Inside time-tampering dialog retry | 🟡 Server error swallowed |
| `settings_screen.dart:71` | `_loadSupportInfo()` | 🟡 UI falls back to defaults |
| `settings_controller.dart:64` | Entire `load()` body | 🔴 All settings silently fail |
| `settings_controller.dart:82` | `updateMyData()` call | 🟢 Intentional — offline graceful |
| `push_notification_service.dart:19` | Firebase `initializeApp()` | 🟡 Firebase fails silently |
| `notification_action_handler.dart:19` | `recheckActivationStatus()` | 🟡 Activation recheck fails silently |
| `file_import_handler.dart:51` | MethodChannel `getInitialFile` | 🟢 Intentional — no file to import |

### 6.3 Catch Blocks That Swallow `Exception` Type

```dart
// settings_controller.dart:64 — this wraps ALL settings loading:
} catch (_) {}

// home_controller.dart:66 — this wraps ALL home data loading:
} catch (_) {}
```

If either of these throws (e.g., DB corruption, type cast failure), the user sees a loading spinner forever or a blank screen — with no error message and no way to diagnose the issue.

---

## 7. Dependency Injection Readiness Audit

### 7.1 Current State: Zero DI

Every service is created with `new ServiceName()` at the point of use:

```
ActivationService()    — instantiated in 20 files / 22 call sites
SettingsService()      — instantiated in 6 call sites
DatabaseHelper.instance — accessed in 20 call sites (acceptable — singleton)
UpdateService()        — instantiated in 2 call sites
DataExportService()    — instantiated in 2 call sites
ContactLauncherService() — instantiated in 4 call sites (const, acceptable)
NotificationApiService() — instantiated in 1 call site
```

### 7.2 Full Map of `ActivationService()` Instantiations

| File | Context |
|---|---|
| `splash_screen.dart` | Screen field |
| `settings_controller.dart` | Controller field |
| `pharmacy_form.dart` | Screen field |
| `pharmacies_screen.dart` | Screen field |
| `new_order_screen.dart` | **Inside build callback** (line 221) — new instance per tap |
| `new_order_screen.dart` | **Inside `_saveOrder()`** (line 794) — new instance per save |
| `pdf_exporter.dart` | Top-level function local |
| `order_details_screen.dart` | **`await ActivationService().getAgentName()`** — anonymous instance |
| `onboarding_screen.dart` | Screen field |
| `medicine_form.dart` | Screen field |
| `medicines_screen.dart` | Screen field |
| `company_form.dart` | Screen field |
| `home_controller.dart` | Controller field |
| `companies_screen.dart` | Screen field |
| `trial_expired_plans_screen.dart` | Screen field |
| `notification_action_handler.dart` | Local variable (×2) |
| `push_notification_service.dart` | Service field |
| `data_export_service.dart` | Service field |
| `offline_limit_screen.dart` | Screen field |

**The most serious violations:**
- `order_details_screen.dart:195`: `await ActivationService().getAgentName()` — creates and discards an instance in a single expression
- `new_order_screen.dart:221,794`: creates new instances inside callbacks that can be called repeatedly

### 7.3 DI Readiness Assessment

| Service | Can be injected easily? | Blocker |
|---|---|---|
| `ActivationService` | ⚠️ Needs refactor first | God-class, must be split |
| `SettingsService` | ✅ Yes | Static methods can be wrapped |
| `DatabaseHelper` | ⚠️ Needs interface | `resetInstance()` complicates mocking |
| `UpdateService` | ✅ Yes | Clean single-responsibility |
| `BackupService` | ✅ Yes | Self-contained |
| `PushNotificationService` | ✅ Yes | Already a singleton |
| `DataExportService` | ✅ Yes | Clean |

---

## 8. Testing Readiness Audit

### 8.1 Current State

| Test Type | Status |
|---|---|
| Unit Tests | ❌ Zero test files |
| Widget Tests | ❌ Zero test files |
| Integration Tests | ❌ Zero test files |
| Test infrastructure | ⚠️ `flutter_test` listed in dev_dependencies only |

### 8.2 What Cannot Be Tested Today (and Why)

| Class | Why It Can't Be Tested |
|---|---|
| `ActivationService` | Creates `AndroidId()`, `DeviceInfoPlugin()`, `SharedPreferences`, `File` directly — no way to inject mocks |
| `DatabaseHelper` | Singleton with static state — `resetInstance()` is brittle |
| `HomeController` | Creates `ActivationService()` directly — can't stub activation results |
| `SettingsController` | Creates `ActivationService()` and `SettingsService()` directly |
| Any screen widget | No mock services available — would hit real DB and real prefs |
| `BackupService` | Depends on `GoogleSignIn`, `DriveApi` — no abstraction to mock |

### 8.3 Minimum Changes to Enable Testing

1. Create `abstract class IActivationService` — extract interface from `ActivationService`
2. Inject `IActivationService` into controllers via constructor
3. Add `get_it` as DI container and register all services
4. Create `FakeActivationService` for tests
5. Wrap `DatabaseHelper` behind `IDatabase` interface

---

## 9. Refactor Priority List

### P0 — Must Fix Before Adding Features

| # | Item | File(s) | Why Critical |
|---|---|---|---|
| 1 | Remove debug `print()` from `OrdersListScreen` | `orders_list_screen.dart:53-56, 84` | Runs production DB query just to print debug info |
| 2 | Remove debug `print()` from `NewOrderScreen` | `new_order_screen.dart:388` | Runs on every medicine selection |
| 3 | Create `AppConstants` class with all magic strings | New file | Prevent key-collision bugs in SharedPreferences |
| 4 | Split `ActivationService` (897 lines) | `activation_service.dart` | God-class blocks all future work |

### P1 — Required for DI and Testability

| # | Item | Files Affected |
|---|---|---|
| 5 | Add `get_it` DI container, register all services | `main.dart` + all screens |
| 6 | Extract `IActivationService` interface | New file |
| 7 | Inject services via constructor into all Controllers | `HomeController`, `SettingsController` |
| 8 | Replace all `ActivationService()` call sites with DI lookup | 20 files |

### P2 — Code Quality Improvements

| # | Item | Notes |
|---|---|---|
| 9 | Replace all `print()` with structured logger | Use `logger` package |
| 10 | Fix `catch (_) {}` in `HomeController.load()` and `SettingsController.load()` | Show error state in UI |
| 11 | Move all SharedPreferences keys to `AppConstants` | End scattered magic strings |
| 12 | Cache `SharedPreferences` instance in `ActivationService` | Stop 30+ redundant `getInstance()` calls |

### P3 — Architecture Layer

| # | Item | Notes |
|---|---|---|
| 13 | Add repository layer for DB access | `PharmacyRepository`, `MedicineRepository`, `OrderRepository` |
| 14 | Move `ActivationService` network calls to `DeviceApiRepository` | Separate HTTP from local storage |
| 15 | Remove empty `lib/widgets/` folder | Dead code cleanup |
| 16 | Fix `FutureBuilder` in `ActivationScreen._buildNotActivatedView()` | Cache future in `initState` |

---

## 10. Recommended Step-by-Step Implementation Plan

### Phase 0 — Zero-Risk Cleanup (Day 1, No Architecture Change)

These changes are safe, have no side-effects, and should be done first:

```
Step 1: Delete lib/widgets/ (empty folder)
Step 2: Remove print() in orders_list_screen.dart lines 53-57
         → Delete the allOrders debug query block entirely
Step 3: Remove print() in new_order_screen.dart line 388
Step 4: Replace print() in backup_service.dart with debugPrint() at minimum
Step 5: Create lib/core/constants/app_constants.dart with:
         - kAppName = 'SmartAgent'
         - kApiAppSalt = 'smart_agent_app'
         - kPdfFontSizeKey, kEnableGiftsKey, kHideCarouselKey
         - kOnboardingCompletedKey
Step 6: Replace all hardcoded 'SmartAgent' string literals with AppConstants.kAppName
Step 7: Replace all SharedPreferences magic strings with AppConstants constants
```

---

### Phase 1 — Service Decomposition (Week 1)

Split `ActivationService` (897 lines) into focused classes:

```
ActivationService (keep, reduce to ~200 lines)
  ↕ delegates to:
  ├── DeviceIdentityService      → getDeviceId() only
  ├── ActivationLocalStorage     → all SharedPreferences read/write
  ├── DeviceApiRepository        → all HTTP calls (create/check/update)
  ├── TimeTamperGuard            → checkTimeTampering(), clearTimeTamperingFlag()
  ├── OfflineLimitGuard          → isOfflineLimitExceeded(), _updateLastOnlineSync()
  └── TrialModeService           → enableTrialMode(), hasTrialExpired(), checkTrialLimit*()
```

**Approach:** Extract one class at a time, keeping `ActivationService` as a facade initially. Each extraction is independently testable.

---

### Phase 2 — Dependency Injection (Week 2)

```dart
// pubspec.yaml — add:
get_it: ^7.6.7

// lib/core/di/service_locator.dart (new file)
final getIt = GetIt.instance;

void setupServiceLocator() {
  // Singletons
  getIt.registerLazySingleton<DatabaseHelper>(() => DatabaseHelper.instance);
  getIt.registerLazySingleton<ActivationLocalStorage>(() => ActivationLocalStorage());
  getIt.registerLazySingleton<DeviceIdentityService>(() => DeviceIdentityService());
  getIt.registerLazySingleton<DeviceApiRepository>(() => DeviceApiRepository());
  getIt.registerLazySingleton<TimeTamperGuard>(() => TimeTamperGuard());
  getIt.registerLazySingleton<OfflineLimitGuard>(() => OfflineLimitGuard());
  getIt.registerLazySingleton<TrialModeService>(() => TrialModeService());
  getIt.registerLazySingleton<ActivationService>(() => ActivationService(...));
  getIt.registerLazySingleton<SettingsService>(() => SettingsService());
  getIt.registerLazySingleton<UpdateService>(() => UpdateService());
  getIt.registerLazySingleton<BackupService>(() => BackupService());
}

// main.dart
void main() async {
  setupServiceLocator();
  // ...
}
```

**Migration strategy:**
1. Register services in `get_it`
2. Update controllers to use `getIt<ActivationService>()` instead of `ActivationService()`
3. Update screens one at a time, starting with the most-used (`SplashScreen`)
4. Delete all `final _service = ServiceName()` field declarations replaced

---

### Phase 3 — Error Handling (Week 3)

```
Step 1: Add `logger` package (^2.0.0)
Step 2: Create lib/core/utils/app_logger.dart
         → wraps logger, configures levels per environment
Step 3: Replace all print() with AppLogger.debug/warning/error
Step 4: Fix catch (_) {} in HomeController.load()
         → set isLoading = false, set error state string, show error in UI
Step 5: Fix catch (_) {} in SettingsController.load()
         → same approach
Step 6: Add FlutterError.onError in main.dart → AppLogger.critical()
```

---

### Phase 4 — Repository Layer (Week 4+)

```
lib/core/repositories/
├── medicine_repository.dart    ← wraps DatabaseHelper medicine queries
├── pharmacy_repository.dart    ← wraps DatabaseHelper pharmacy queries
├── order_repository.dart       ← wraps DatabaseHelper order queries
└── company_repository.dart     ← wraps DatabaseHelper company queries
```

Each repository takes `DatabaseHelper` as a constructor parameter → fully mockable for tests.

---

### Phase 5 — First Test Suite

After Phases 1–4, the following test files become possible:

```
test/
├── unit/
│   ├── activation_local_storage_test.dart
│   ├── time_tamper_guard_test.dart
│   ├── offline_limit_guard_test.dart
│   ├── trial_mode_service_test.dart
│   ├── device_identity_service_test.dart
│   └── settings_service_test.dart
├── widget/
│   ├── home_screen_test.dart     (with mocked HomeController)
│   ├── splash_screen_test.dart   (with mocked ActivationService)
│   └── offline_limit_screen_test.dart
└── integration/
    └── activation_flow_test.dart
```

---

## 11. File-Level Criticality Ranking

| Rank | File | Lines | Reason |
|---|---|---|---|
| 1 🔴 | `activation_service.dart` | 897 | God-class, blocks everything |
| 2 🔴 | `orders_list_screen.dart` | 317 | Debug `print()` in production |
| 3 🔴 | `new_order_screen.dart` | 1518 | Largest file, multiple DI violations, debug print |
| 4 🟡 | `settings_screen.dart` | 1493 | 2nd largest, multiple service instantiations |
| 5 🟡 | `home_controller.dart` | 145 | 3× empty catch, direct DI violations |
| 6 🟡 | `settings_controller.dart` | 142 | 2× empty catch, raw string keys |
| 7 🟡 | `backup_service.dart` | 244 | 5× `print()` in production |
| 8 🟡 | `notification_action_handler.dart` | 134 | Creates 2 anonymous `ActivationService()` instances |
| 9 🟢 | `push_notification_service.dart` | 375 | Minor DI violation |
| 10 🟢 | `settings_service.dart` | 178 | Hardcoded personal contacts |

---

## Summary Table

| Issue Type | Count | Severity |
|---|---|---|
| Direct `ActivationService()` instantiations | 22 | 🔴 |
| Direct `SettingsService()` instantiations | 6 | 🟡 |
| Raw `print()` calls | 13 | 🔴–🟡 |
| Empty/swallowed `catch` blocks | 11 | 🔴–🟢 |
| Hardcoded config values | 7 | 🟡 |
| Magic string SharedPreferences keys | 4 | 🟡 |
| Files with no test coverage | All (100%) | 🔴 |
| God-class violations (>500 lines + mixed responsibilities) | 2 (`ActivationService`, `NewOrderScreen`) | 🔴 |

---

*Audit completed April 12, 2026 — No code was modified during this audit.*
*Next step: Begin Phase 0 cleanup (zero-risk changes) before any architectural refactoring.*

