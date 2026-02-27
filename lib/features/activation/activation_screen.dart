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
  bool _isVerified = false;
  bool _trialExpired = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkActivation();
    _checkTrialExpiration();
  }

  Future<void> _checkTrialExpiration() async {
    try {
      final expired = await _activationService.hasTrialExpired();
      if (expired) {
        // Disable trial mode permanently
        await _activationService.disableTrialMode();
        setState(() {
          _trialExpired = true;
          _errorMessage =
              'انتهت النسخة التجريبية. يرجى التواصل مع المطور لتفعيل التطبيق.';
        });
      }
    } catch (e) {
      // Ignore errors in trial expiration check
    }
  }

  Future<void> _checkActivation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if already activated
      final isActivated = await _activationService.isActivated();

      if (isActivated) {
        setState(() {
          _isActivated = true;
          _isVerified = true;
          _isLoading = false;
        });
        _navigateToHome();
        return;
      }

      // Check if activation API has been called
      final hasBeenCalled = await _activationService.hasActivationBeenCalled();
      final verifiedStatus = await _activationService.getActivationVerified();

      if (hasBeenCalled && verifiedStatus != null) {
        // API was already called, use saved status
        if (verifiedStatus) {
          setState(() {
            _isActivated = true;
            _isVerified = true;
            _isLoading = false;
          });
          _navigateToHome();
        } else {
          // is_verified = 0, show trial mode
          setState(() {
            _isActivated = false;
            _isVerified = false;
            _isLoading = false;
          });
        }
        return;
      }

      // First time: Call API
      final agentName = await _activationService.getAgentName();
      final agentPhone = await _activationService.getAgentPhone();
      final deviceId = await _activationService.getDeviceId();

      if (agentName.isEmpty || agentPhone.isEmpty) {
        setState(() {
          _errorMessage = 'بيانات المندوب غير موجودة';
          _isLoading = false;
        });
        return;
      }

      // Send activation request
      final verified = await _activationService.sendActivationRequest(
        agentName,
        agentPhone,
        deviceId,
      );

      if (verified) {
        // is_verified = 1: Success
        setState(() {
          _isActivated = true;
          _isVerified = true;
          _isLoading = false;
        });
        _navigateToHome();
      } else {
        // is_verified = 0: Show trial mode
        setState(() {
          _isActivated = false;
          _isVerified = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isActivated = false;
        _isVerified = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _navigateToTrial() async {
    try {
      // Check if trial was already used once
      final usedOnce = await _activationService.hasTrialBeenUsedOnce();
      if (usedOnce) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم استخدام النسخة التجريبية مسبقاً'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Enable trial mode
      await _activationService.enableTrialMode();

      // Navigate to trial/home mode (allow access)
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _navigateToHome() {
    // Navigate to home screen
    // Note: You'll need to set up routes in your MaterialApp
    Navigator.of(context).pushReplacementNamed('/home');
  }

  void _navigateToSubscriptionPlans() {
    // Navigate to subscription plans screen
    Navigator.of(context).pushNamed('/subscription-plans');
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
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ] else ...[
            const Text(
              'يرجى التواصل مع المطوّر',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 24),
            // Subscription plans button
            ElevatedButton.icon(
              onPressed: _navigateToSubscriptionPlans,
              icon: const Icon(Icons.payment),
              label: const Text(
                'عرض باقات الاشتراك',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                minimumSize: const Size(200, 50),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            // Contact developer button
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Open contact method (phone, email, etc.)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى التواصل مع المطور للتفعيل'),
                  ),
                );
              },
              icon: const Icon(Icons.contact_support),
              label: const Text(
                'تواصل مع المطور',
                style: TextStyle(fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                minimumSize: const Size(200, 50),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (_errorMessage != null) ...[
            // Show retry button if there's an error
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
          ] else if (!_isVerified && !_trialExpired) ...[
            // Show trial button if is_verified = 0 and trial not expired
            // Check if trial was already used
            FutureBuilder<bool>(
              future: _activationService.hasTrialBeenUsedOnce(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                final usedOnce = snapshot.data ?? false;
                if (usedOnce) {
                  return const SizedBox.shrink(); // Don't show trial button
                }
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: _navigateToTrial,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        minimumSize: const Size(200, 50),
                        backgroundColor: Colors.orange,
                      ),
                      child: const Text(
                        'تجربة النسخة التجريبية',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
            TextButton(
              onPressed: _checkActivation,
              child: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ] else if (_trialExpired) ...[
            // Trial expired - navigate directly to trial expired plans screen
            Builder(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed('/trial-expired-plans');
                  }
                });
                return const SizedBox.shrink();
              },
            ),
          ],
        ],
      ),
    );
  }
}
