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
    setState(() {
      _isChecking = true;
    });

    try {
      // Try to reconnect to server
      final success = await _activationService.checkDeviceStatus();
      
      if (success && mounted) {
        // Connection successful - clear offline limit flag
        final stillExceeded = await _activationService.isOfflineLimitExceeded();
        
        if (!stillExceeded) {
          // Offline limit cleared - navigate to home
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          // Still exceeded - show error
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يزال الوقت المتاح للعمل بدون إنترنت قد انتهى'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Connection failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل الاتصال بالسيرفر. يرجى التحقق من الاتصال بالإنترنت'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
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
