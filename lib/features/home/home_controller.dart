import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/db/database_helper.dart';
import '../../core/services/activation_service.dart';

class HomeStats {
  final int todayOrders;
  final int totalOrders;
  final int activePharmacies;
  final int totalMedicines;

  const HomeStats({
    this.todayOrders = 0,
    this.totalOrders = 0,
    this.activePharmacies = 0,
    this.totalMedicines = 0,
  });
}

enum AccountStatus { active, trial, expired, unknown }

class HomeController extends ChangeNotifier {
  final ActivationService _activation = ActivationService();
  final DatabaseHelper _db = DatabaseHelper.instance;

  String agentName = '';
  AccountStatus status = AccountStatus.unknown;
  HomeStats stats = const HomeStats();
  bool hideCarousel = false;
  bool isLoading = true;

  static const String _hideCarouselKey = 'hide_home_carousel';

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Agent name
      agentName = await _activation.getAgentName();

      // Carousel
      hideCarousel = prefs.getBool(_hideCarouselKey) ?? false;

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
    } catch (_) {}

    isLoading = false;
    notifyListeners();
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

      return HomeStats(
        todayOrders: (todayResult.first['c'] as int?) ?? 0,
        totalOrders: (totalResult.first['c'] as int?) ?? 0,
        activePharmacies: (pharmaciesResult.first['c'] as int?) ?? 0,
        totalMedicines: (medicinesResult.first['c'] as int?) ?? 0,
      );
    } catch (_) {
      return const HomeStats();
    }
  }

  Future<void> dismissCarousel() async {
    hideCarousel = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideCarouselKey, true);
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
    } catch (_) {}
    return null;
  }
}

