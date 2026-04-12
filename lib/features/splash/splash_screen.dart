import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/activation_service.dart';
import '../../core/services/push_notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Brand colours ──────────────────────────────────────────────────────────
  static const Color _bgTop    = Color(0xFF1E3F73);
  static const Color _bgBottom = Color(0xFF0B1D3A);
  static const Color _glow     = Color(0xFF4A8FD4);

  final ActivationService _activationService = getIt<ActivationService>();

  // Logo bounce
  late AnimationController _logoCtrl;
  late Animation<double>    _scale;
  late Animation<double>    _logoOpacity;

  // Pulsing ring (starts after logo lands)
  late AnimationController _pulseCtrl;
  late Animation<double>    _pulseScale;
  late Animation<double>    _pulseOpacity;

  // Text reveal
  late AnimationController  _textCtrl;
  late Animation<double>    _textOpacity;
  late Animation<Offset>    _textSlide;

  @override
  void initState() {
    super.initState();

    // ── Logo bounce controller (1 300 ms) ───────────────────────────────────
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    // 0 → 1.18 (fast grow-up) → 0.93 (pull back) → 1.0 (settle)
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.18, end: 0.93)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.93, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
    ]).animate(_logoCtrl);

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.30, curve: Curves.easeIn),
      ),
    );

    // ── Pulse ring controller (1 800 ms, repeating) ─────────────────────────
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.55).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );

    // ── Text reveal controller (700 ms) ─────────────────────────────────────
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.45),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    // Start logo → then pulse + text
    _logoCtrl.forward().then((_) {
      _pulseCtrl.repeat();
      _textCtrl.forward();
    });


    _navigateToNextScreen();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PushNotificationService.instance.flushPendingNavigation(context);
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  // ── Navigation (unchanged logic) ───────────────────────────────────────────
  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool(AppConstants.kOnboardingCompleted) ?? false;
    if (!mounted) return;

    if (!onboardingCompleted) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
      return;
    }

    final hasAgentData = await _activationService.hasAgentData();
    if (!mounted) return;

    if (!hasAgentData) {
      Navigator.of(context).pushReplacementNamed('/agent-registration');
      return;
    }

    await PushNotificationService.instance.retryTokenSync();

    final timeTampered = await _activationService.checkTimeTampering();
    if (timeTampered && mounted) {
      await _showTimeTamperingDialog();
      return;
    }

    final offlineLimitExceeded = await _activationService.isOfflineLimitExceeded();
    if (offlineLimitExceeded && mounted) {
      Navigator.of(context).pushReplacementNamed('/offline-limit');
      return;
    }

    try {
      await _activationService.checkDeviceStatus();
    } catch (_) {}

    if (!mounted) return;

    final isActivated = await _activationService.isActivated();
    if (!mounted) return;

    final licenseExpired = await _activationService.isLicenseExpired();
    if (licenseExpired) {
      Navigator.of(context).pushReplacementNamed('/trial-expired-plans');
      return;
    }

    final trialExpired = await _activationService.hasTrialExpired();
    if (trialExpired) {
      await _activationService.disableTrialMode();
      Navigator.of(context).pushReplacementNamed('/trial-expired-plans');
      return;
    }

    if (isActivated) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/activation');
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Animated logo ──────────────────────────────────────────────
              Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_logoCtrl, _pulseCtrl]),
                  builder: (context, _) {
                    return SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Expanding pulse ring
                          Transform.scale(
                            scale: _pulseScale.value,
                            child: Opacity(
                              opacity: _pulseOpacity.value * _logoOpacity.value,
                              child: Container(
                                width: 168,
                                height: 168,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _glow,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Soft glow backdrop
                          Opacity(
                            opacity: _logoOpacity.value,
                            child: Container(
                              width: 158,
                              height: 158,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(36),
                                boxShadow: [
                                  BoxShadow(
                                    color: _glow.withValues(alpha: 0.55),
                                    blurRadius: 45,
                                    spreadRadius: 8,
                                  ),
                                  BoxShadow(
                                    color: _glow.withValues(alpha: 0.25),
                                    blurRadius: 90,
                                    spreadRadius: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Logo image with bounce scale
                          Transform.scale(
                            scale: _scale.value,
                            child: Opacity(
                              opacity: _logoOpacity.value,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: Image.asset(
                                  'assets/images/app_logo.png',
                                  width: 152,
                                  height: 152,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 36),

              // ── App name reveal ────────────────────────────────────────────
              FadeTransition(
                opacity: _textOpacity,
                child: SlideTransition(
                  position: _textSlide,
                  child: Column(
                    children: [
                      const Text(
                        'المندوب الذكي',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.4,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'SMART  AGENT',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.55),
                          letterSpacing: 4,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // ── Bottom loading indicator ───────────────────────────────────
              FadeTransition(
                opacity: _textOpacity,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 52),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.45),
                      ),
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

  // ── Time-tampering dialog (unchanged) ──────────────────────────────────────
  Future<void> _showTimeTamperingDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'تحذير',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'تم اكتشاف تغيير في وقت الجهاز. يرجى تصحيح الوقت.',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _activationService.checkDeviceStatus();
                await _activationService.clearTimeTamperingFlag();
              } catch (_) {}
              if (mounted) _navigateToNextScreen();
            },
            child: const Text(
              'إعادة الاتصال بالسيرفر',
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}
