import 'package:flutter/material.dart';
import '../../core/services/activation_service.dart';
import '../../core/widgets/custom_app_bar.dart';

class OfflineLimitScreen extends StatefulWidget {
  const OfflineLimitScreen({super.key});

  @override
  State<OfflineLimitScreen> createState() => _OfflineLimitScreenState();
}

class _OfflineLimitScreenState extends State<OfflineLimitScreen> {
  final ActivationService _activationService = ActivationService();
  bool _isChecking = false;

  Future<void> _checkConnection() async {
    // Guard: prevent multiple simultaneous calls (e.g., rapid double-tap)
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    try {
      // Try to reconnect to server.
      // checkDeviceStatus() already calls _updateLastOnlineSync() internally,
      // which clears the offline-limit flag on a successful response.
      final success = await _activationService.checkDeviceStatus();

      if (!mounted) return;

      if (success) {
        // Server confirmed the device is active — offline limit is now cleared.
        // No need to re-check isOfflineLimitExceeded(); trust the server response.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم التحقق بنجاح! الاتصال بالسيرفر فعّال'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Await the delay so _isChecking stays true and the button remains
        // disabled — prevents the user from tapping again before navigation.
        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        // Server responded but device is not verified
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الجهاز غير مفعّل. يرجى تفعيل الاشتراك'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل الاتصال بالسيرفر. يرجى التحقق من الاتصال بالإنترنت'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Only reset the flag if the widget is still mounted.
      // If navigation succeeded the widget is disposed — mounted will be false.
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'تحذير'),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_off,
                  size: 80,
                  color: Colors.orange,
                ),
                const SizedBox(height: 32),
                const Text(
                  'يرجى الاتصال بالإنترنت للتحقق من الاشتراك',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'تم تجاوز الحد المسموح للعمل بدون إنترنت (72 ساعة). يرجى الاتصال بالإنترنت للتحقق من حالة الاشتراك.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                FilledButton.icon(
                  onPressed: _isChecking ? null : _checkConnection,
                  icon: _isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    _isChecking ? 'جاري التحقق...' : 'التحقق من الاتصال',
                    style: const TextStyle(fontSize: 18),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    minimumSize: const Size(200, 50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
