import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/services/activation_service.dart';
import '../../../core/services/contact_launcher_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/di/service_locator.dart';
import '../widgets/setting_tile.dart';

class SupportSettingsPage extends StatefulWidget {
  const SupportSettingsPage({super.key});

  @override
  State<SupportSettingsPage> createState() => _SupportSettingsPageState();
}

class _SupportSettingsPageState extends State<SupportSettingsPage> {
  final ContactLauncherService _contactLauncher = const ContactLauncherService();
  final _activationService = getIt<ActivationService>();
  String _appVersion = '';

  // Review state
  bool _reviewSent = true;
  int _reviewStars = 0;
  final _reviewCommentController = TextEditingController();
  bool _isSubmittingReview = false;
  String? _reviewError;

  // Agent info for message templates
  String _agentName = '';
  String _agentPhone = '';
  String _deviceId = '';

  SupportContactInfo _support = const SupportContactInfo(
    email: SettingsService.defaultSupportEmail,
    telegram: SettingsService.defaultSupportTelegram,
    whatsapp: SettingsService.defaultSupportWhatsapp,
  );

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _reviewCommentController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      _appVersion = '1.0.0';
    }
    try {
      final support = await SettingsService.getSupportInfo();
      _support = support;
    } catch (_) {}
    try {
      _agentName = await _activationService.getAgentName();
      _agentPhone = await _activationService.getAgentPhone();
      _deviceId = await _activationService.getDeviceId();
    } catch (_) {}
    try {
      final sent = await _activationService.hasReviewBeenSent();
      _reviewSent = sent;
    } catch (_) {
      _reviewSent = false;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A1628) : const Color(0xFFEEF2F8),
      appBar: const CustomAppBar(
        title: 'الدعم والتواصل',
        showNotifications: false,
        showSettings: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildSupportSection(),
          if (!_reviewSent) _buildReviewSection(isDark),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    return SettingSection(
      title: 'الدعم والمساعدة',
      icon: Icons.support_agent_outlined,
      children: [
        ValueListenableBuilder<int>(
          valueListenable: PushNotificationService.instance.unreadCount,
          builder: (_, unread, __) {
            return SettingTile(
              icon: Icons.notifications_outlined,
              title: 'الإشعارات',
              subtitle: unread > 0 ? 'غير مقروء: $unread' : 'عرض الإشعارات الأخيرة',
              trailing: unread > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('$unread',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  : null,
              onTap: () => Navigator.of(context).pushNamed('/notifications'),
            );
          },
        ),
        SettingTile(
          icon: Icons.support_agent,
          title: 'تواصل مع خدمة العملاء',
          subtitle: 'إرسال استفسار أو مشكلة',
          onTap: () => _showSupportActionSheet(
            actionTitle: 'تواصل مع خدمة العملاء',
            emailSubject: 'تواصل من تطبيق المندوب الذكي',
            messageTemplate: _buildSupportMessageTemplate(),
          ),
        ),
        SettingTile(
          icon: Icons.lightbulb_outline,
          iconColor: Colors.amber.shade700,
          title: 'طلب ميزة جديدة',
          subtitle: 'شاركنا اقتراحك لتطوير التطبيق',
          onTap: () => _showSupportActionSheet(
            actionTitle: 'طلب ميزة جديدة',
            emailSubject: 'اقتراح ميزة جديدة - تطبيق المندوب الذكي',
            messageTemplate: _buildFeatureRequestMessageTemplate(),
          ),
        ),
        SettingTile(
          icon: Icons.info_outline,
          title: 'حول التطبيق',
          subtitle: 'المندوب الذكي — إدارة الطلبيات',
          showDivider: false,
          onTap: _showAbout,
        ),
      ],
    );
  }

  Widget _buildReviewSection(bool isDark) {
    final theme = Theme.of(context);
    return SettingSection(
      title: 'قيّم التطبيق',
      icon: Icons.star_outline_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              return GestureDetector(
                onTap: _isSubmittingReview
                    ? null
                    : () => setState(() => _reviewStars = starIndex),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    starIndex <= _reviewStars ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 38,
                    color: starIndex <= _reviewStars
                        ? Colors.amber.shade600
                        : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reviewCommentController,
          enabled: !_isSubmittingReview,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'أضف تعليقاً (اختياري)...',
            hintTextDirection: TextDirection.rtl,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
        ),
        if (_reviewError != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_reviewError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textDirection: TextDirection.rtl),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: FilledButton.icon(
            onPressed: (_isSubmittingReview || _reviewStars == 0) ? null : _submitReview,
            icon: _isSubmittingReview
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                : const Icon(Icons.send_rounded),
            label: Text(
              _isSubmittingReview ? 'جارٍ الإرسال...' : 'إرسال التقييم',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  // ── Actions ──

  Future<void> _submitReview() async {
    if (_reviewStars == 0) return;
    setState(() { _isSubmittingReview = true; _reviewError = null; });
    try {
      final success = await _activationService.submitReview(
        stars: _reviewStars,
        comment: _reviewCommentController.text.trim().isEmpty ? null : _reviewCommentController.text.trim(),
      );
      if (!mounted) return;
      if (success) {
        await _activationService.markReviewSent();
        if (mounted) {
          setState(() { _reviewSent = true; _isSubmittingReview = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('شكراً! تم إرسال تقييمك بنجاح.'), backgroundColor: Colors.green),
          );
        }
      } else {
        setState(() { _isSubmittingReview = false; _reviewError = 'فشل الإرسال. يرجى المحاولة مجدداً.'; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _isSubmittingReview = false; _reviewError = 'حدث خطأ: ${e.toString()}'; });
    }
  }

  String _buildSupportMessageTemplate() {
    return '''مرحباً،
لدي استفسار/مشكلة بخصوص تطبيق المندوب الذكي.

تفاصيل الطلب:

---
اسم المندوب: $_agentName
رقم الهاتف: $_agentPhone
معرّف الجهاز: $_deviceId
إصدار التطبيق: $_appVersion
---''';
  }

  String _buildFeatureRequestMessageTemplate() {
    return '''مرحباً،
لدي اقتراح ميزة جديدة لتطبيق المندوب الذكي.

اسم الميزة:
وصف مختصر:
الفائدة المتوقعة:

---
اسم المندوب: $_agentName
رقم الهاتف: $_agentPhone
معرّف الجهاز: $_deviceId
إصدار التطبيق: $_appVersion
---''';
  }

  void _showSupportActionSheet({
    required String actionTitle,
    required String emailSubject,
    required String messageTemplate,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(ctx).padding.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 42, height: 4, margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(999))),
            Text(actionTitle,
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textDirection: TextDirection.rtl),
            const SizedBox(height: 6),
            Text('اختر طريقة التواصل المناسبة',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
              textDirection: TextDirection.rtl),
            const SizedBox(height: 14),
            _buildContactMethodTile(ctx: ctx, icon: Icons.email_outlined, title: 'البريد الإلكتروني',
              subtitle: _support.email, color: Colors.blue,
              onTap: () async { Navigator.pop(ctx); await _launchSupport(ContactMethodType.email, messageTemplate, emailSubject: emailSubject); }),
            const SizedBox(height: 10),
            _buildContactMethodTile(ctx: ctx, icon: Icons.telegram, title: 'تلجرام',
              subtitle: _support.telegram, color: const Color(0xFF0088CC),
              onTap: () async { Navigator.pop(ctx); await _launchSupport(ContactMethodType.telegram, messageTemplate); }),
            const SizedBox(height: 10),
            _buildContactMethodTile(ctx: ctx, icon: Icons.chat_outlined, title: 'واتساب',
              subtitle: _support.whatsapp, color: Colors.green,
              onTap: () async { Navigator.pop(ctx); await _launchSupport(ContactMethodType.whatsapp, messageTemplate); }),
          ],
        ),
      ),
    );
  }

  Widget _buildContactMethodTile({
    required BuildContext ctx, required IconData icon, required String title,
    required String subtitle, required Color color, required Future<void> Function() onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            color: color.withValues(alpha: 0.08),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), textDirection: TextDirection.rtl),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700), textDirection: TextDirection.rtl),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: Colors.grey.shade700),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchSupport(ContactMethodType method, String message, {String? emailSubject}) async {
    final result = await _contactLauncher.launch(
      method: method, support: _support, message: message, emailSubject: emailSubject,
    );
    if (!mounted || result.success) return;
    _contactLauncher.showLaunchError(context, method: method, result: result);
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'المندوب الذكي',
      applicationVersion: _appVersion,
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset('assets/images/app_logo.png', width: 56, height: 56),
      ),
      children: [
        const Text('تطبيق لإدارة الطلبيات والفواتير محلياً بدون الحاجة للإنترنت.', textDirection: TextDirection.rtl),
      ],
    );
  }
}

