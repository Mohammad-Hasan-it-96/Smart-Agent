import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
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
import 'home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
  void dispose() {
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
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _ctrl,
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'المندوب الذكي',
          automaticallyImplyLeading: false,
          actions: _ctrl.status == AccountStatus.trial
              ? [
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'تجريبية',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ]
              : null,
        ),
        body: Consumer<HomeController>(
          builder: (context, ctrl, _) {
            if (ctrl.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: ctrl.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildGreetingHeader(ctrl),
                  if (!ctrl.hideCarousel) ...[
                    const SizedBox(height: 16),
                    _buildCarousel(context),
                    const SizedBox(height: 8),
                    _buildDots(),
                  ],
                  const SizedBox(height: 20),
                  _buildStatsRow(ctrl),
                  const SizedBox(height: 24),
                  _buildSectionTitle('القائمة الرئيسية'),
                  const SizedBox(height: 12),
                  _buildMenuGrid(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  GREETING HEADER
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildGreetingHeader(HomeController ctrl) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = ctrl.agentName.isNotEmpty ? ctrl.agentName : 'المندوب';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A237E), const Color(0xFF283593)]
              : [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.person, color: Colors.white, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أهلاً، $name 👋',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _greetingByTime(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          // Status badge
          _buildStatusBadge(ctrl.status),
        ],
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
  //  CAROUSEL
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCarousel(BuildContext context) {
    final theme = Theme.of(context);
    final slides = [
      _Slide('مرحباً بك أيها المندوب!', 'نظام إدارة الطلبيات الذكي',
          Icons.rocket_launch_rounded, [theme.colorScheme.primary, theme.colorScheme.secondary]),
      _Slide('سجل الطلبيات بسهولة', 'إنشاء وإدارة الطلبيات بضغطة واحدة',
          Icons.shopping_cart_rounded, [const Color(0xFF00897B), const Color(0xFF26A69A)]),
      _Slide('إدارة الأدوية والشركات', 'تنظيم كامل لقاعدة بياناتك',
          Icons.medication_rounded, [const Color(0xFF7B1FA2), const Color(0xFFAB47BC)]),
    ];

    return SizedBox(
      height: 170,
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
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: s.colors,
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(s.subtitle,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(s.icon, size: 40, color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
          // Close button
          Positioned(
            top: 6,
            right: 8,
            child: GestureDetector(
              onTap: () {
                _timer?.cancel();
                _ctrl.dismissCarousel();
              },
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = _currentPage == i;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: active ? 22 : 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.primary.withValues(alpha: 0.25),
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  STATS ROW
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildStatsRow(HomeController ctrl) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        _statCard('طلبيات اليوم', '${ctrl.stats.todayOrders}',
            Icons.today_rounded, const Color(0xFF1E88E5), isDark),
        const SizedBox(width: 10),
        _statCard('إجمالي الطلبيات', '${ctrl.stats.totalOrders}',
            Icons.receipt_long_rounded, const Color(0xFF43A047), isDark),
        const SizedBox(width: 10),
        _statCard('الصيدليات', '${ctrl.stats.activePharmacies}',
            Icons.local_pharmacy_rounded, const Color(0xFF8E24AA), isDark),
      ],
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
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

  Widget _buildSectionTitle(String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  MENU GRID
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildMenuGrid(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final items = [
      _Menu('طلبية جديدة', Icons.add_shopping_cart_rounded,
          const Color(0xFF00897B), () => _navigate(const NewOrderScreen())),
      _Menu('الطلبيات', Icons.receipt_long_rounded,
          const Color(0xFF1E88E5), () => _navigate(const OrdersListScreen())),
      _Menu('الأدوية', Icons.medication_rounded,
          const Color(0xFFE53935), () => _navigate(const MedicinesScreen())),
      _Menu('الشركات', Icons.business_rounded,
          const Color(0xFF7B1FA2), () => _navigate(const CompaniesScreen())),
      _Menu('الصيدليات', Icons.local_pharmacy_rounded,
          const Color(0xFFFF8F00), () => _navigate(const PharmaciesScreen())),
      _Menu('الإعدادات', Icons.settings_rounded,
          const Color(0xFF546E7A), () => _navigate(const SettingsScreen())),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.92,
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
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.icon, color: item.color, size: 28),
                ),
                const SizedBox(height: 10),
                Text(
                  item.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
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
