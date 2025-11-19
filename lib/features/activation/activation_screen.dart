import 'package:flutter/material.dart';
import '../../core/services/activation_service.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final ActivationService _activationService = ActivationService();
  bool _isLoading = true;
  bool _isActivated = false;

  @override
  void initState() {
    super.initState();
    _checkActivation();
  }

  Future<void> _checkActivation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if already activated
      final isActivated = await _activationService.isActivated();

      if (isActivated) {
        setState(() {
          _isActivated = true;
          _isLoading = false;
        });
        _navigateToHome();
        return;
      }

      // Get device ID
      final deviceId = await _activationService.getDeviceId();

      // Try online activation
      final activationResult =
          await _activationService.checkOnlineActivation(deviceId);

      if (activationResult) {
        // Save activation status
        await _activationService.saveActivationStatus(true);
        setState(() {
          _isActivated = true;
          _isLoading = false;
        });
        _navigateToHome();
      } else {
        // Activation failed
        setState(() {
          _isActivated = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isActivated = false;
        _isLoading = false;
      });
    }
  }

  void _navigateToHome() {
    // Navigate to home screen
    // Note: You'll need to set up routes in your MaterialApp
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _isActivated
                ? const SizedBox.shrink() // Will navigate away
                : _buildNotActivatedView(),
      ),
    );
  }

  Widget _buildNotActivatedView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 80,
            color: Colors.red,
          ),
          const SizedBox(height: 32),
          const Text(
            'التطبيق يحتاج تفعيل',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 16),
          const Text(
            'يرجى التواصل مع المطوّر',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _checkActivation,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              minimumSize: const Size(200, 50),
            ),
            child: const Text(
              'إعادة المحاولة',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}
