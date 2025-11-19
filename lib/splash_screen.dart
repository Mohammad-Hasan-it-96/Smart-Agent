import 'package:flutter/material.dart';
import 'core/services/activation_service.dart';
import 'features/home/home_screen.dart';
import 'features/activation/activation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ActivationService _activationService = ActivationService();

  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // Wait 1 second
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // Check activation status
    final isActivated = await _activationService.isActivated();

    if (!mounted) return;

    // Navigate based on activation status
    if (isActivated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ActivationScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Center(
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Icon(
                Icons.shopping_cart,
                size: 100,
                color: Colors.white,
              ),
              SizedBox(height: 24),
              // App Name
              Text(
                'المندوب الذكي',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textDirection: TextDirection.rtl,
              ),
              SizedBox(height: 48),
              // Loading indicator
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
