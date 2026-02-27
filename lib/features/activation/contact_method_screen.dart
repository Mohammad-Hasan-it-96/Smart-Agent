import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/services/activation_service.dart';

class ContactMethodScreen extends StatefulWidget {
  final String selectedPlanId;

  const ContactMethodScreen({
    super.key,
    required this.selectedPlanId,
  });

  @override
  State<ContactMethodScreen> createState() => _ContactMethodScreenState();
}

class _ContactMethodScreenState extends State<ContactMethodScreen> {
  final ActivationService _activationService = ActivationService();
  String? _selectedMethod;
  String _agentName = '';
  String _agentPhone = '';
  String _deviceId = '';
  bool _isLoading = true;
  String _activationMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAgentData();
  }

  Future<void> _loadAgentData() async {
    try {
      final name = await _activationService.getAgentName();
      final phone = await _activationService.getAgentPhone();
      final deviceId = await _activationService.getDeviceId();

      setState(() {
        _agentName = name;
        _agentPhone = phone;
        _deviceId = deviceId;
        _isLoading = false;
        _updateActivationMessage();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getPlanDurationText() {
    switch (widget.selectedPlanId) {
      case 'half_year':
        return 'نصف سنوية';
      case 'yearly':
        return 'سنوية';
      default:
        return 'غير محدد';
    }
  }

  void _updateActivationMessage() {
    setState(() {
      _activationMessage = '''مرحباً،
أرغب بتفعيل تطبيق المندوب الذكي
الخطة المختارة: ${_getPlanDurationText()}
اسم المندوب: $_agentName
رقم الهاتف: $_agentPhone
معرّف الجهاز: $_deviceId''';
    });
  }

  void _onMethodSelected(String method) {
    setState(() {
      _selectedMethod = method;
    });
  }

  void _copyMessage() {
    Clipboard.setData(ClipboardData(text: _activationMessage));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الرسالة'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onSendRequest() async {
    if (_selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار طريقة التواصل'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Send activation request to backend API (non-blocking)
    _sendActivationRequestToAPI();

    // Launch contact app
    try {
      if (_selectedMethod == 'email') {
        await _launchEmail();
      } else if (_selectedMethod == 'telegram') {
        await _launchTelegram();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء فتح التطبيق: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _sendActivationRequestToAPI() async {
    // Save activation request state immediately to prevent duplicate requests
    // This is saved even if API call fails, to prevent user from sending multiple requests
    await _activationService.saveActivationRequestState(
      widget.selectedPlanId,
    );

    // Send API request in background (non-blocking)
    // Don't wait for it to complete - launch contact app immediately
    try {
      final success = await _activationService.sendSubscriptionActivationRequest(
        deviceId: _deviceId,
        agentName: _agentName,
        agentPhone: _agentPhone,
        planId: widget.selectedPlanId,
        contactMethod: _selectedMethod!,
      );

      if (success && mounted) {
        // Request sent successfully - show subtle confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب التفعيل إلى الخادم'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      // If API fails, don't show error - user can still send via contact app
      // The request can be retried later if needed
      // State is already saved, so duplicate requests are prevented
    } catch (e) {
      // Silently handle API errors - don't block user flow
      // The request will be retried later if needed
      // State is already saved, so duplicate requests are prevented
    }
  }

  Future<void> _launchEmail() async {
    const email = 'mohamad.hasan.it.96@gmail.com';
    const subject = 'طلب تفعيل تطبيق المندوب الذكي';
    final body = Uri.encodeComponent(_activationMessage);
    
    final emailUri = Uri.parse('mailto:$email?subject=${Uri.encodeComponent(subject)}&body=$body');

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح تطبيق البريد الإلكتروني. يرجى نسخ الرسالة وإرسالها يدوياً.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح تطبيق البريد الإلكتروني. يرجى نسخ الرسالة وإرسالها يدوياً.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _launchTelegram() async {
    // Telegram phone number for direct contact
    const telegramPhone = '963983820430'; // Syrian number without +
    final message = Uri.encodeComponent(_activationMessage);

    // Try native Telegram app first (tg:// scheme)
    // Send direct message using phone number
    final tgUri = Uri.parse('tg://resolve?phone=$telegramPhone&text=$message');

    try {
      final launched = await launchUrl(
        tgUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Fallback to web Telegram using phone
        final webUri = Uri.parse('https://t.me/+$telegramPhone?text=$message');
        final webLaunched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );

        if (!webLaunched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر فتح تطبيق تيليجرام. يرجى نسخ الرسالة وإرسالها يدوياً.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Try web Telegram as fallback
      try {
        final webUri = Uri.parse('https://wa.me/$telegramPhone?text=$message');
        await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر فتح تطبيق تيليجرام. يرجى نسخ الرسالة وإرسالها يدوياً.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'اختر طريقة التواصل'),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'اختر طريقة التواصل'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'يرجى اختيار طريقة التواصل المفضلة لإتمام عملية التفعيل:',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // Email option
                    _buildMethodCard(
                      theme: theme,
                      methodId: 'email',
                      title: 'البريد الإلكتروني',
                      icon: Icons.email,
                      description: 'سيتم التواصل معك عبر البريد الإلكتروني',
                      isSelected: _selectedMethod == 'email',
                      onTap: () => _onMethodSelected('email'),
                    ),
                    const SizedBox(height: 16),
                    // Telegram option
                    _buildMethodCard(
                      theme: theme,
                      methodId: 'telegram',
                      title: 'تيليجرام',
                      icon: Icons.send,
                      description: 'سيتم التواصل معك عبر تيليجرام',
                      isSelected: _selectedMethod == 'telegram',
                      onTap: () => _onMethodSelected('telegram'),
                    ),
                    if (_selectedMethod != null) ...[
                      const SizedBox(height: 32),
                      // Activation message section
                      _buildActivationMessage(theme),
                    ],
                  ],
                ),
              ),
            ),
            // Send request button at bottom
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: FilledButton(
                  onPressed: _selectedMethod != null ? _onSendRequest : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text(
                    'إرسال طلب التفعيل',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodCard({
    required ThemeData theme,
    required String methodId,
    required String title,
    required IconData icon,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.05)
              : null,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.grey[700],
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // Title and description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
            // Radio button
            Radio<String>(
              value: methodId,
              groupValue: _selectedMethod,
              onChanged: (value) => _onMethodSelected(value!),
              activeColor: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivationMessage(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'رسالة طلب التفعيل:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                IconButton(
                  onPressed: _copyMessage,
                  icon: const Icon(Icons.copy),
                  tooltip: 'نسخ الرسالة',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: SelectableText(
                _activationMessage,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'يمكنك نسخ الرسالة وإرسالها عبر ${_selectedMethod == 'email' ? 'البريد الإلكتروني' : 'تيليجرام'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      ),
    );
  }
}
