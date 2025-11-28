import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/utils/slide_page_route.dart';
import '../../core/services/activation_service.dart';
import '../companies/companies_screen.dart';
import '../medicines/medicines_screen.dart';
import '../pharmacies/pharmacies_screen.dart';
import '../orders/new_order_screen.dart';
import '../orders/orders_list_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  final ActivationService _activationService = ActivationService();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
    _checkTrialExpiration();
  }

  Future<void> _checkTrialExpiration() async {
    // Check if trial has expired
    final trialExpired = await _activationService.hasTrialExpired();
    if (trialExpired && mounted) {
      // Disable trial mode and redirect to activation
      await _activationService.disableTrialMode();
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/activation',
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('انتهت النسخة التجريبية – يرجى التواصل مع المطور'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        if (_currentPage < 2) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const CustomAppBar(title: 'الصفحة الرئيسية'),
      body: SafeArea(
        child: Column(
          children: [
            // Header Carousel Slider
            _buildCarouselSlider(theme),
            const SizedBox(height: 8),
            _buildPageIndicators(theme),
            const SizedBox(height: 16),

            // Main Menu Grid
            Expanded(
              child: _buildMenuGrid(context, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselSlider(ThemeData theme) {
    final slides = [
      _SlideData(
        title: 'مرحباً بك أيها المندوب!',
        subtitle: 'نظام إدارة الطلبيات الذكي',
        icon: Icons.person,
        gradient: [
          theme.colorScheme.primary,
          theme.colorScheme.primary.withValues(alpha: 0.7),
        ],
      ),
      _SlideData(
        title: 'سجل الطلبيات بسهولة',
        subtitle: 'إنشاء وإدارة الطلبيات بضغطة واحدة',
        icon: Icons.shopping_cart,
        gradient: [
          theme.colorScheme.secondary,
          theme.colorScheme.secondary.withValues(alpha: 0.7),
        ],
      ),
      _SlideData(
        title: 'إدارة الأدوية والشركات',
        subtitle: 'تنظيم كامل لقاعدة بياناتك',
        icon: Icons.medication,
        gradient: [
          theme.colorScheme.tertiary,
          theme.colorScheme.tertiary.withValues(alpha: 0.7),
        ],
      ),
    ];

    return SizedBox(
      height: 200,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemCount: slides.length,
        itemBuilder: (context, index) {
          final slide = slides[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: slide.gradient,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slide.title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              slide.subtitle,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          slide.icon,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageIndicators(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Container(
          width: _currentPage == index ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: _currentPage == index
                ? theme.colorScheme.primary
                : theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }

  Widget _buildMenuGrid(BuildContext context, ThemeData theme) {
    final menuItems = [
      _MenuItem(
        title: 'الشركات',
        icon: Icons.business,
        onTap: () {
          Navigator.push(
            context,
            SlidePageRoute(
              page: const CompaniesScreen(),
              direction: SlideDirection.rightToLeft,
            ),
          );
        },
      ),
      _MenuItem(
        title: 'الأدوية',
        icon: Icons.medication,
        onTap: () {
          Navigator.push(
            context,
            SlidePageRoute(
              page: const MedicinesScreen(),
              direction: SlideDirection.rightToLeft,
            ),
          );
        },
      ),
      _MenuItem(
        title: 'الصيدليات',
        icon: Icons.local_pharmacy,
        onTap: () {
          Navigator.push(
            context,
            SlidePageRoute(
              page: const PharmaciesScreen(),
              direction: SlideDirection.rightToLeft,
            ),
          );
        },
      ),
      _MenuItem(
        title: 'إنشاء طلبية جديدة',
        icon: Icons.add_shopping_cart,
        color: theme.colorScheme.tertiary,
        onTap: () {
          Navigator.push(
            context,
            SlidePageRoute(
              page: const NewOrderScreen(),
              direction: SlideDirection.rightToLeft,
            ),
          );
        },
      ),
      _MenuItem(
        title: 'الطلبيات السابقة',
        icon: Icons.history,
        onTap: () {
          Navigator.push(
            context,
            SlidePageRoute(
              page: const OrdersListScreen(),
              direction: SlideDirection.rightToLeft,
            ),
          );
        },
      ),
      _MenuItem(
        title: 'الإعدادات',
        icon: Icons.settings,
        onTap: () {
          Navigator.push(
            context,
            SlidePageRoute(
              page: const SettingsScreen(),
              direction: SlideDirection.rightToLeft,
            ),
          );
        },
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          final item = menuItems[index];
          return _buildMenuCard(context, item, theme);
        },
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, _MenuItem item, ThemeData theme) {
    return Card(
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (item.color ?? theme.colorScheme.primary)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    item.icon,
                    size: 28,
                    color: item.color ?? theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  item.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideData {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;

  _SlideData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });
}

class _MenuItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  _MenuItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.color,
  });
}
