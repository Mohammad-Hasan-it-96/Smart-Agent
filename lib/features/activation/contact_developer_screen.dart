import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/services/activation_service.dart';

class ContactDeveloperScreen extends StatefulWidget {
  const ContactDeveloperScreen({super.key});

  @override
  State<ContactDeveloperScreen> createState() => _ContactDeveloperScreenState();
}

class _ContactDeveloperScreenState extends State<ContactDeveloperScreen> {
  final ActivationService _activationService = ActivationService();
  final TextEditingController _messageController = TextEditingController();
  String? _selectedMethod;
  String _agentName = '';
  String _agentPhone = '';
  String _deviceId = '';
  bool _isLoading = true;
  bool _isSending = false;

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
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _buildMessageWithDetails() {
    final customMessage = _messageController.text.trim();
    final details = '''
---
البيانات الشخصية:
الاسم: $_agentName
الرقم: $_agentPhone
معرّف الجهاز: $_deviceId
---''';

    return customMessage.isEmpty
        ? details
        : '$customMessage\n$details';
  }

  void _copyMessage() {
    final fullMessage = _buildMessageWithDetails();
    Clipboard.setData(ClipboardData(text: fullMessage));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الرسالة'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendViaEmail() async {
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة الرسالة أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      const email = 'mohamad.hasan.it.96@gmail.com';
      const subject = 'تواصل من المندوب الذكي';
      final body = Uri.encodeComponent(_buildMessageWithDetails());

      final emailUri = Uri.parse(
        'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=$body',
      );

      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح البريد الإلكتروني. يرجى نسخ الرسالة وإرسالها يدويًا.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء فتح البريد'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _sendViaTelegram() async {
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة الرسالة أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      const telegramPhone = '963983820430';
      final message = Uri.encodeComponent(_buildMessageWithDetails());

      // Try native Telegram app first
      final tgUri = Uri.parse('tg://resolve?phone=$telegramPhone&text=$message');

      final launched = await launchUrl(
        tgUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Fallback to web Telegram
        final webUri = Uri.parse('https://t.me/+$telegramPhone?text=$message');
        final webLaunched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );

        if (!webLaunched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر فتح تليجرام. يرجى نسخ الرسالة وإرسالها يدويًا.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء فتح تليجرام'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _onSend() async {
    if (_selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار طريقة التواصل'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedMethod == 'email') {
      await _sendViaEmail();
    } else if (_selectedMethod == 'telegram') {
      await _sendViaTelegram();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'تواصل مع المطور'),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'تواصل مع المطور'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    const Text(
                      'أرسل رسالتك للمطور',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 16),

                    // Message input
                    TextField(
                      controller: _messageController,
                      maxLines: 6,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالتك هنا...',
                        hintTextDirection: TextDirection.rtl,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Preview
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'معاينة الرسالة:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
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
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: SelectableText(
                                _buildMessageWithDetails(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: Colors.white,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Contact method selection
                    const Text(
                      'اختر طريقة التواصل:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 12),

                    // Email option
                    _buildMethodCard(
                      theme: theme,
                      methodId: 'email',
                      title: 'البريد الإلكتروني',
                      icon: Icons.email,
                      description: 'mohamad.hasan.it.96@gmail.com',
                      isSelected: _selectedMethod == 'email',
                      onTap: () => setState(() => _selectedMethod = 'email'),
                    ),
                    const SizedBox(height: 12),

                    // Telegram option
                    _buildMethodCard(
                      theme: theme,
                      methodId: 'telegram',
                      title: 'تيليجرام',
                      icon: Icons.send,
                      description: '+963983820430',
                      isSelected: _selectedMethod == 'telegram',
                      onTap: () => setState(() => _selectedMethod = 'telegram'),
                    ),
                  ],
                ),
              ),
            ),

            // Send button
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
                child: Column(
                  children: [
                    FilledButton(
                      onPressed: _isSending ? null : _onSend,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'إرسال الرسالة',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                  ],
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: isSelected ? theme.colorScheme.primary : Colors.grey[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: methodId,
              groupValue: _selectedMethod,
              onChanged: (value) => setState(() => _selectedMethod = value),
              activeColor: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

