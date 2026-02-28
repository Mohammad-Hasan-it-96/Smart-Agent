import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/services/activation_service.dart';

class TrialExpiredPlansScreen extends StatefulWidget {
  const TrialExpiredPlansScreen({super.key});

  @override
  State<TrialExpiredPlansScreen> createState() => _TrialExpiredPlansScreenState();
}

class _TrialExpiredPlansScreenState extends State<TrialExpiredPlansScreen> {
  final ActivationService _activationService = ActivationService();
  String? _selectedPlanId;
  bool _isLoading = true;
  bool _requestAlreadySent = false;
  String _agentName = '';
  String _agentPhone = '';
  String _deviceId = '';
  String _activationMessage = '';
  bool _isLoadingAgentData = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _contactSectionKey = GlobalKey();
  bool _contactButtonsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkActivationRequestStatus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkActivationRequestStatus() async {
    final requested = await _activationService.hasActivationRequestBeenSent();
    setState(() {
      _requestAlreadySent = requested;
      _isLoading = false;
    });
  }

  void _onPlanSelected(String planId) async {
    setState(() {
      _selectedPlanId = planId;
      _contactButtonsEnabled = false; // Disable until data is loaded
    });
    
    // Load agent data and generate message when plan is selected
    await _loadAgentDataAndGenerateMessage();
    
    // Enable contact buttons and scroll to contact section
    if (mounted) {
      _enableContactButtons();
      _scrollToContactSection();
    }
  }

  void _enableContactButtons() {
    setState(() {
      _contactButtonsEnabled = true;
    });
  }

  void _scrollToContactSection() {
    // Wait for the widget to be built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_contactSectionKey.currentContext != null) {
        Scrollable.ensureVisible(
          _contactSectionKey.currentContext!,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          alignment: 0.1, // Scroll to show contact section near top
        );
      }
    });
  }

  Future<void> _loadAgentDataAndGenerateMessage() async {
    if (_agentName.isEmpty || _agentPhone.isEmpty || _deviceId.isEmpty) {
      setState(() {
        _isLoadingAgentData = true;
      });

      try {
        final name = await _activationService.getAgentName();
        final phone = await _activationService.getAgentPhone();
        final deviceId = await _activationService.getDeviceId();

        setState(() {
          _agentName = name;
          _agentPhone = phone;
          _deviceId = deviceId;
          _isLoadingAgentData = false;
          _updateActivationMessage();
        });
      } catch (e) {
        setState(() {
          _isLoadingAgentData = false;
        });
      }
    } else {
      _updateActivationMessage();
    }
  }

  String _getPlanDurationText() {
    switch (_selectedPlanId) {
      case 'half_year':
        return 'نصف سنوية';
      case 'yearly':
        return 'سنوية';
      default:
        return 'غير محدد';
    }
  }

  void _updateActivationMessage() {
    if (_selectedPlanId == null) return;
    
    setState(() {
      _activationMessage = '''مرحباً،
أرغب بتفعيل تطبيق المندوب الذكي
الخطة المختارة: ${_getPlanDurationText()}
اسم المندوب: $_agentName
رقم الهاتف: $_agentPhone
معرّف الجهاز: $_deviceId''';
    });
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
      } else {
        // Save activation request state and send to API
        await _sendActivationRequest('email');
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
    const telegramUsername = 'smartAgentSupport';
    final message = Uri.encodeComponent(_activationMessage);

    final tgUri = Uri.parse('tg://resolve?domain=$telegramUsername&text=$message');
    
    try {
      final launched = await launchUrl(
        tgUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Fallback to web Telegram
        final webUri = Uri.parse('https://t.me/$telegramUsername?text=$message');
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
        } else {
          await _sendActivationRequest('telegram');
        }
      } else {
        await _sendActivationRequest('telegram');
      }
    } catch (e) {
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

  Future<void> _sendActivationRequest(String contactMethod) async {
    try {
      await _activationService.saveActivationRequestState(_selectedPlanId!);
      
      final success = await _activationService.sendSubscriptionActivationRequest(
        deviceId: _deviceId,
        agentName: _agentName,
        agentPhone: _agentPhone,
        planId: _selectedPlanId!,
        contactMethod: contactMethod,
      );

      if (success && mounted) {
        setState(() {
          _requestAlreadySent = true;
        });
      }
    } catch (e) {
      // Silently handle API errors
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'انتهت النسخة التجريبية'),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If activation request was already sent, show message instead
    if (_requestAlreadySent) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'انتهت النسخة التجريبية'),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'تم إرسال طلب التفعيل، يرجى انتظار رد المطور',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'سيتم التواصل معك قريباً عبر طريقة التواصل المختارة',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'انتهت النسخة التجريبية'),
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
                    // Plan 1: الخطة النصف سنوية
                    _buildPlanCard(
                      theme: theme,
                      planId: 'half_year',
                      title: 'الخطة النصف سنوية',
                      durationMonths: 6,
                      isSelected: _selectedPlanId == 'half_year',
                      onTap: () => _onPlanSelected('half_year'),
                    ),
                    const SizedBox(height: 16),
                    // Plan 2: الخطة السنوية
                    _buildPlanCard(
                      theme: theme,
                      planId: 'yearly',
                      title: 'الخطة السنوية',
                      durationMonths: 12,
                      isSelected: _selectedPlanId == 'yearly',
                      onTap: () => _onPlanSelected('yearly'),
                    ),
                    // Success message card (animated)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, -0.2),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            )),
                            child: child,
                          ),
                        );
                      },
                      child: _selectedPlanId != null
                          ? _buildSuccessCard(theme)
                          : const SizedBox.shrink(key: ValueKey('empty')),
                    ),
                    // Contact options (animated)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.2),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            )),
                            child: child,
                          ),
                        );
                      },
                      child: _selectedPlanId != null
                          ? _buildContactOptions(theme)
                          : const SizedBox.shrink(key: ValueKey('empty')),
                    ),
                    // Invisible anchor for scrolling
                    if (_selectedPlanId != null)
                      SizedBox(
                        key: _contactSectionKey,
                        height: 1,
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

  Widget _buildPlanCard({
    required ThemeData theme,
    required String planId,
    required String title,
    required int durationMonths,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : (theme.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87),
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
                Radio<String>(
                  value: planId,
                  groupValue: _selectedPlanId,
                  onChanged: (value) => _onPlanSelected(value!),
                  activeColor: theme.colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'المدة: $durationMonths ${durationMonths == 12 ? 'شهر' : 'أشهر'}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? (theme.brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87)
                        : (theme.brightness == Brightness.dark
                            ? Colors.grey[300]
                            : Colors.grey[700]),
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  size: 18,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'السعر: (سيتم تحديده لاحقاً)',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? (theme.brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.8)
                            : Colors.black87.withOpacity(0.8))
                        : (theme.brightness == Brightness.dark
                            ? Colors.grey[300]
                            : Colors.grey[700]),
                    fontStyle: FontStyle.italic,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getSelectedPlanTitle() {
    switch (_selectedPlanId) {
      case 'half_year':
        return 'الخطة النصف سنوية';
      case 'yearly':
        return 'الخطة السنوية';
      default:
        return 'باقة';
    }
  }

  Widget _buildSuccessCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? Colors.green.shade900.withOpacity(0.3)
        : Colors.green.shade50;
    final borderColor = isDark
        ? Colors.green.shade700
        : Colors.green.shade200;
    final iconBackgroundColor = isDark
        ? Colors.green.shade800.withOpacity(0.5)
        : Colors.green.shade100;
    final iconColor = isDark
        ? Colors.green.shade300
        : Colors.green.shade700;
    final textColor = isDark
        ? Colors.green.shade200
        : Colors.green.shade900;
    final subtitleColor = isDark
        ? Colors.green.shade300
        : Colors.green.shade800;

    return Container(
      key: const ValueKey('success-card'),
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.green.shade800 : Colors.green.shade100)
                .withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✅ تم اختيار ${_getSelectedPlanTitle()}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 4),
                Text(
                  'يرجى اختيار طريقة التواصل لإكمال التفعيل',
                  style: TextStyle(
                    fontSize: 14,
                    color: subtitleColor,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOptions(ThemeData theme) {
    if (_isLoadingAgentData) {
      return Container(
        key: const ValueKey('loading'),
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      key: const ValueKey('contact-options'),
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'اختر طريقة التواصل:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Email button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            decoration: _contactButtonsEnabled
                ? BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  )
                : null,
            child: FilledButton.icon(
              onPressed: _contactButtonsEnabled && !_isLoadingAgentData
                  ? _launchEmail
                  : null,
              icon: Icon(
                Icons.email,
                color: _contactButtonsEnabled ? Colors.white : Colors.grey,
              ),
              label: Text(
                'البريد الإلكتروني',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _contactButtonsEnabled ? Colors.white : Colors.grey,
                ),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _contactButtonsEnabled
                    ? theme.colorScheme.primary
                    : Colors.grey.shade400,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade400,
                disabledForegroundColor: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Telegram button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            decoration: _contactButtonsEnabled
                ? BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        blurRadius: 6,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  )
                : null,
            child: OutlinedButton.icon(
              onPressed: _contactButtonsEnabled && !_isLoadingAgentData
                  ? _launchTelegram
                  : null,
              icon: Icon(
                Icons.send,
                color: _contactButtonsEnabled
                    ? theme.colorScheme.primary
                    : Colors.grey,
              ),
              label: Text(
                'تيليجرام',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _contactButtonsEnabled
                      ? theme.colorScheme.primary
                      : Colors.grey,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: _contactButtonsEnabled
                    ? theme.colorScheme.primary
                    : Colors.grey,
                side: BorderSide(
                  color: _contactButtonsEnabled
                      ? theme.colorScheme.primary
                      : Colors.grey,
                  width: 2,
                ),
                disabledForegroundColor: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Message preview
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'معاينة الرسالة:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      IconButton(
                        onPressed: _copyMessage,
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: 'نسخ الرسالة',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      _activationMessage,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: theme.brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
