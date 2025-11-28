import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/activation_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final ActivationService _activationService = ActivationService();
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _showAppName = false;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // Scale animation: 0.0 -> 1.0
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    // Opacity animation: 0.0 -> 1.0
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeIn),
      ),
    );

    // Start animations
    _controller.forward();

    // Show app name after logo animation starts
    Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _showAppName = true;
        });
      }
    });

    // Navigate after animation completes
    _navigateToNextScreen();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigateToNextScreen() async {
    // Wait for animation to complete (1100ms) + small delay
    await Future.delayed(const Duration(milliseconds: 1300));

    if (!mounted) return;

    // Check if onboarding has been completed
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    if (!mounted) return;

    // If onboarding not completed, show onboarding first
    if (!onboardingCompleted) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
      return;
    }

    // Check if agent data exists
    final hasAgentData = await _activationService.hasAgentData();

    if (!mounted) return;

    // If no agent data, navigate to registration screen
    if (!hasAgentData) {
      Navigator.of(context).pushReplacementNamed('/agent-registration');
      return;
    }

    // Check activation status
    final isActivated = await _activationService.isActivated();

    if (!mounted) return;

    // Check if trial has expired
    final trialExpired = await _activationService.hasTrialExpired();
    if (trialExpired) {
      // Disable trial mode and redirect to activation
      await _activationService.disableTrialMode();
      Navigator.of(context).pushReplacementNamed('/activation');
      return;
    }

    // Navigate based on activation status
    if (isActivated) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/activation');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final backgroundColor =
        isDark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    backgroundColor,
                    backgroundColor.withValues(alpha: 0.95),
                  ]
                : [
                    primaryColor.withValues(alpha: 0.1),
                    primaryColor.withValues(alpha: 0.05),
                  ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo with Glowing Background
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _opacityAnimation.value,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              primaryColor.withValues(alpha: 0.3),
                              primaryColor.withValues(alpha: 0.1),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.2),
                              blurRadius: 60,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.shopping_cart_rounded,
                            size: 80,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // App Name with Fade Animation
              AnimatedOpacity(
                opacity: _showAppName ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeIn,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: _showAppName ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Text(
                        'المندوب الذكي',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? theme.colorScheme.onSurface
                              : primaryColor,
                          letterSpacing: 1.2,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 48),

              // Subtle Loading Indicator (appears after logo animation)
              AnimatedOpacity(
                opacity: _showAppName ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      primaryColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
