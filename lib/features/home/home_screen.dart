import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/update_dialog.dart';
import '../../core/utils/slide_page_route.dart';
import '../../core/services/update_service.dart';
import '../companies/companies_screen.dart';
import '../medicines/medicines_screen.dart';
import '../pharmacies/pharmacies_screen.dart';
import '../orders/new_order_screen.dart';
import '../orders/orders_list_screen.dart';
import '../settings/settings_screen.dart';
import '../search/search_screen.dart';
import '../gifts/gifts_screen.dart';
import 'home_controller.dart';

/// Global RouteObserver — register once in MaterialApp's navigatorObservers.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  late final HomeController _ctrl;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = HomeController();
    _ctrl.load().then((_) {
      if (!_ctrl.hideCarousel) _startAutoSlide();
      _checkExpiration();
    });
    _checkForUpdates();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // Another screen was popped and we're visible again → refresh stats
    _ctrl.refreshStats();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _timer?.cancel();
    _pageController.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final info = await UpdateService().checkForUpdate(pkg.version);
      if (info != null && mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) showUpdateDialog(context, info);
        });
      }
    } catch (_) {}
  }

  Future<void> _checkExpiration() async {
    final route = await _ctrl.checkExpiration();
    if (route != null && mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
    }
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pageController.hasClients || _ctrl.hideCarousel) return;
      _currentPage = (_currentPage + 1) % 3;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _navigate(Widget page) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      SlidePageRoute(page: page, direction: SlideDirection.rightToLeft),
    ).then((_) {
      // Refresh stats when returning from any sub-screen
      _ctrl.refreshStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ChangeNotifierProvider.value(
      value: _ctrl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A1628) : const Color(0xFFEEF2F8),
        appBar: CustomAppBar(
          title: 'المندوب الذكي',
          automaticallyImplyLeading: false,
          showNotifications: true,
          showSettings: true,
          actions: [
            if (_ctrl.status == AccountStatus.trial)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'تجريبية',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        // Search FAB
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _navigate(const SearchScreen()),
          icon: const Icon(Icons.search_rounded),
          label: const Text('بحث', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        body: Consumer<HomeController>(
          builder: (context, ctrl, _) {
            if (ctrl.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 3,
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: ctrl.load,
              color: AppTheme.primaryColor,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildGreetingHeader(ctrl),
                  if (ctrl.status == AccountStatus.trial) ...[
                    const SizedBox(height: 12),
                    _buildTrialWarningCta(),
                  ],
                  if (!ctrl.hideCarousel) ...[
                    const SizedBox(height: 16),
                    _buildCarousel(context),
                    const SizedBox(height: 10),
                    _buildDots(),
                  ],
                  const SizedBox(height: 24),
                  _buildSectionTitle('ابدأ من هنا', Icons.grid_view_rounded),
                  const SizedBox(height: 14),
                  _buildMenuGrid(context),
                  const SizedBox(height: 24),
                  _buildSectionTitle('ملخص اليوم', Icons.bar_chart_rounded),
                  const SizedBox(height: 14),
                  _buildStatsRow(ctrl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  GREETING HEADER — Glassmorphism
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildGreetingHeader(HomeController ctrl) {
    final name = ctrl.agentName.isNotEmpty ? ctrl.agentName : 'المندوب';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A4275), Color(0xFF0D2A50)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A4275).withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -20,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            // Glass overlay panel
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Logo avatar
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'أهلاً، $name 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _greetingByTime(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 13,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  _buildStatusBadge(ctrl.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greetingByTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير ☀️';
    if (hour < 17) return 'مساء النور 🌤️';
    return 'مساء الخير 🌙';
  }

  Widget _buildStatusBadge(AccountStatus status) {
    Color bg;
    String label;
    switch (status) {
      case AccountStatus.active:
        bg = Colors.green;
        label = 'مفعّل';
        break;
      case AccountStatus.trial:
        bg = Colors.orange;
        label = 'تجريبي';
        break;
      case AccountStatus.expired:
        bg = Colors.red;
        label = 'منتهي';
        break;
      case AccountStatus.unknown:
        bg = Colors.grey;
        label = 'غير مفعّل';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.25),
        border: Border.all(color: bg.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CAROUSEL — Glassmorphism slides
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCarousel(BuildContext context) {
    final slides = [
      _Slide('مرحباً بك أيها المندوب!', 'نظام إدارة الطلبيات الذكي',
          Icons.rocket_launch_rounded,
          [const Color(0xFF1A4275), const Color(0xFF2563A8)]),
      _Slide('سجل الطلبيات بسهولة', 'إنشاء وإدارة الطلبيات بضغطة واحدة',
          Icons.shopping_cart_rounded,
          [const Color(0xFF006450), const Color(0xFF00897B)]),
      _Slide('إدارة الأدوية والشركات', 'تنظيم كامل لقاعدة بياناتك',
          Icons.medication_rounded,
          [const Color(0xFF5B2C8D), const Color(0xFF7B1FA2)]),
    ];

    return SizedBox(
      height: 158,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: slides.length,
            itemBuilder: (_, i) {
              final s = slides[i];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: s.colors,
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: s.colors[0].withValues(alpha: 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -20,
                        right: -20,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    s.subtitle,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 13,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Icon(s.icon, size: 36, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Close button
          Positioned(
            top: 8,
            right: 10,
            child: GestureDetector(
              onTap: () {
                _timer?.cancel();
                _ctrl.dismissCarousel();
              },
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = _currentPage == i;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: active ? 24 : 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: active
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withValues(alpha: 0.2),
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  STATS ROW — Glassmorphism cards
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildStatsRow(HomeController ctrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          children: [
            _statCard('طلبيات اليوم', '${ctrl.stats.todayOrders}',
                Icons.today_rounded, const Color(0xFF1A4275), isDark),
            const SizedBox(width: 10),
            _statCard('الإجمالي', '${ctrl.stats.totalOrders}',
                Icons.receipt_long_rounded, const Color(0xFF00897B), isDark),
            const SizedBox(width: 10),
            _statCard('الصيدليات', '${ctrl.stats.activePharmacies}',
                Icons.local_pharmacy_rounded, const Color(0xFF7B1FA2), isDark),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _statCard('الأدوية', '${ctrl.stats.totalMedicines}',
                Icons.medication_rounded, const Color(0xFFE53935), isDark),
            const SizedBox(width: 10),
            _statCard('الشركات', '${ctrl.stats.totalCompanies}',
                Icons.business_rounded, const Color(0xFF2563A8), isDark),
            const SizedBox(width: 10),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : color.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? const Color(0xFF8096AA) : const Color(0xFF8096AA),
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  SECTION TITLE
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSectionTitle(String text, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0D1F35),
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildTrialWarningCta() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withValues(alpha: 0.15),
            Colors.orange.withValues(alpha: 0.05),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'أنت تستخدم النسخة التجريبية حالياً',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/subscription-plans'),
            icon: const Icon(Icons.workspace_premium_rounded, size: 18),
            label: const Text('اختيار باقة والاشتراك', style: TextStyle(fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  MENU GRID — Glassmorphism tiles
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildMenuGrid(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      _Menu('طلبية جديدة', Icons.add_shopping_cart_rounded,
          const Color(0xFF00897B), () => _navigate(const NewOrderScreen())),
      _Menu('الطلبيات', Icons.receipt_long_rounded,
          const Color(0xFF1A4275), () => _navigate(const OrdersListScreen())),
      _Menu('الأدوية', Icons.medication_rounded,
          const Color(0xFFE53935), () => _navigate(const MedicinesScreen())),
      _Menu('الشركات', Icons.business_rounded,
          const Color(0xFF2563A8), () => _navigate(const CompaniesScreen())),
      _Menu('الصيدليات', Icons.local_pharmacy_rounded,
          const Color(0xFFFF8F00), () => _navigate(const PharmaciesScreen())),
      _Menu('الهدايا', Icons.card_giftcard_rounded,
          const Color(0xFF00897B), () => _navigate(const GiftsScreen())),
      _Menu('الإعدادات', Icons.settings_rounded,
          const Color(0xFF546E7A), () => _navigate(const SettingsScreen())),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.9,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return GestureDetector(
          onTap: item.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : item.color.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.10),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(item.icon, color: item.color, size: 26),
                ),
                const SizedBox(height: 10),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0D1F35),
                    fontFamily: 'Cairo',
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Data classes ─────────────────────────────────────────────────

class _Slide {
  final String title, subtitle;
  final IconData icon;
  final List<Color> colors;
  _Slide(this.title, this.subtitle, this.icon, this.colors);
}

class _Menu {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _Menu(this.label, this.icon, this.color, this.onTap);
}
