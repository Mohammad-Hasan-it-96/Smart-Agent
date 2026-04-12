import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/db/database_helper.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/activation_service.dart';
import '../../core/utils/app_logger.dart';

class HomeStats {
  final int todayOrders;
  final int totalOrders;
  final int activePharmacies;
  final int totalMedicines;
  final int totalCompanies;

  const HomeStats({
    this.todayOrders = 0,
    this.totalOrders = 0,
    this.activePharmacies = 0,
    this.totalMedicines = 0,
    this.totalCompanies = 0,
  });
}

enum AccountStatus { active, trial, expired, unknown }

class HomeController extends ChangeNotifier {
  final ActivationService _activation = getIt<ActivationService>();
  final DatabaseHelper _db = getIt<DatabaseHelper>();

  String agentName = '';
  AccountStatus status = AccountStatus.unknown;
  HomeStats stats = const HomeStats();
  bool hideCarousel = false;
  bool isLoading = true;

  // Key now lives in AppConstants — no local duplicate needed.

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Agent name
      agentName = await _activation.getAgentName();

      // Carousel
      hideCarousel = prefs.getBool(AppConstants.kHideHomeCarousel) ?? false;

      // Status
      final isActivated = await _activation.isActivated();
      final isTrial = await _activation.isTrialMode();
      final isExpired = await _activation.isLicenseExpired();

      if (isActivated) {
        status = AccountStatus.active;
      } else if (isTrial) {
        status = AccountStatus.trial;
      } else if (isExpired) {
        status = AccountStatus.expired;
      } else {
        status = AccountStatus.unknown;
      }

      // Stats
      stats = await _loadStats();
    } catch (e) {
      AppLogger.e('HomeController', 'load failed', e);
    }

    isLoading = false;
    notifyListeners();
  }

  /// Lightweight refresh — only reloads stats from DB without
  /// touching activation state, carousel, or agent name.
  Future<void> refreshStats() async {
    try {
      stats = await _loadStats();
      notifyListeners();
    } catch (e) {
      AppLogger.w('HomeController', 'refreshStats failed', e);
    }
  }

  Future<HomeStats> _loadStats() async {
    try {
      final db = await _db.database;

      // Today's date prefix (yyyy-MM-dd)
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final todayResult = await db.rawQuery(
        "SELECT COUNT(*) as c FROM orders WHERE created_at LIKE ?",
        ['$todayStr%'],
      );
      final totalResult = await db.rawQuery(
        "SELECT COUNT(*) as c FROM orders",
      );
      final pharmaciesResult = await db.rawQuery(
        "SELECT COUNT(*) as c FROM pharmacies",
      );
      final medicinesResult = await db.rawQuery(
        "SELECT COUNT(*) as c FROM medicines",
      );
      final companiesResult = await db.rawQuery(
        "SELECT COUNT(*) as c FROM companies",
      );

      return HomeStats(
        todayOrders: (todayResult.first['c'] as int?) ?? 0,
        totalOrders: (totalResult.first['c'] as int?) ?? 0,
        activePharmacies: (pharmaciesResult.first['c'] as int?) ?? 0,
        totalMedicines: (medicinesResult.first['c'] as int?) ?? 0,
        totalCompanies: (companiesResult.first['c'] as int?) ?? 0,
      );
    } catch (e) {
      AppLogger.e('HomeController', '_loadStats failed', e);
      return const HomeStats();
    }
  }

  Future<void> dismissCarousel() async {
    hideCarousel = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.kHideHomeCarousel, true);
  }

  /// Check trial / license expiration. Returns route name to redirect, or null.
  Future<String?> checkExpiration() async {
    try {
      final offlineExceeded = await _activation.isOfflineLimitExceeded();
      if (offlineExceeded) return '/offline-limit';

      final licenseExpired = await _activation.isLicenseExpired();
      if (licenseExpired) return '/trial-expired-plans';

      final trialExpired = await _activation.hasTrialExpired();
      if (trialExpired) {
        await _activation.disableTrialMode();
        return '/trial-expired-plans';
      }
    } catch (e) {
      AppLogger.e('HomeController', 'checkExpiration failed', e);
    }
    return null;
  }
}

