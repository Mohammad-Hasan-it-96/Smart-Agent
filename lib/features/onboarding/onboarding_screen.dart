import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/activation_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final ActivationService _activationService = ActivationService();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.shopping_cart_rounded,
      title: 'مرحباً بك في المندوب الذكي',
      description: 'تطبيق متكامل لإدارة الطلبيات والمبيعات بسهولة وفعالية',
      color: Colors.blue,
    ),
    OnboardingPage(
      icon: Icons.inventory_2_rounded,
      title: 'إدارة شاملة للمنتجات',
      description: 'قم بإدارة الأدوية والشركات والصيدليات بكل سهولة',
      color: Colors.green,
    ),
    OnboardingPage(
      icon: Icons.receipt_long_rounded,
      title: 'إنشاء الفواتير والطلبيات',
      description: 'أنشئ الطلبيات والفواتير بسرعة واحفظها كملفات PDF',
      color: Colors.orange,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    // Save onboarding completion status
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (!mounted) return;

    // Check if agent data exists
    final hasAgentData = await _activationService.hasAgentData();

    if (!mounted) return;

    // Navigate based on app state
    if (!hasAgentData) {
      Navigator.of(context).pushReplacementNamed('/agent-registration');
    } else {
      final isActivated = await _activationService.isActivated();
      if (!mounted) return;

      if (isActivated) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/activation');
      }
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? theme.scaffoldBackgroundColor
          : theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: Text(
                    'تخطي',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index], theme, isDark);
                },
              ),
            ),

            // Page Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => _buildIndicator(index == _currentPage, theme),
              ),
            ),

            const SizedBox(height: 32),

            // Next/Start Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: theme.colorScheme.primary,
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1
                        ? 'بدء الاستخدام'
                        : 'التالي',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration/Icon
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  page.color.withValues(alpha: 0.2),
                  page.color.withValues(alpha: 0.05),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: page.color.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              page.icon,
              size: 100,
              color: page.color,
            ),
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            page.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),

          const SizedBox(height: 24),

          // Description
          Text(
            page.description,
            style: TextStyle(
              fontSize: 16,
              color: isDark
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive, ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.primary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

