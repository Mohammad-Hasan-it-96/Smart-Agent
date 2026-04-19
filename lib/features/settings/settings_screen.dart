import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/activation_service.dart';
import '../../core/services/data_export_service.dart';
import '../../core/services/contact_launcher_service.dart';
import '../../core/services/update_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/models/warehouse.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/update_dialog.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/phone_validator.dart';
import '../../core/di/service_locator.dart';
import 'settings_controller.dart';
import 'widgets/setting_tile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _ctrl;
  final ContactLauncherService _contactLauncher = const ContactLauncherService();
  final _dataExport = DataExportService();
  final _activationService = getIt<ActivationService>();
  String _appVersion = '';
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isCheckingActivation = false;
  bool _isCheckingUpdates = false;

  // ── Review state ──────────────────────────────────────────────────────
  bool _reviewSent = true; // optimistic hide until loaded
  int _reviewStars = 0;
  final _reviewCommentController = TextEditingController();
  bool _isSubmittingReview = false;
  String? _reviewError;

  SupportContactInfo _support = const SupportContactInfo(
    email: SettingsService.defaultSupportEmail,
    telegram: SettingsService.defaultSupportTelegram,
    whatsapp: SettingsService.defaultSupportWhatsapp,
  );

  @override
  void initState() {
    super.initState();
    _ctrl = SettingsController();
    _ctrl.load();
    _loadVersion();
    _loadSupportInfo();
    _loadReviewStatus();
  }

  @override
  void dispose() {
    _reviewCommentController.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    } catch (e) {
      AppLogger.w('SettingsScreen', '_loadVersion failed', e);
      if (mounted) setState(() => _appVersion = '1.0.0');
    }
  }

  Future<void> _loadSupportInfo() async {
    try {
      final support = await SettingsService.getSupportInfo();
      if (mounted) {
        setState(() => _support = support);
      }
    } catch (e) {
      AppLogger.w('SettingsScreen', '_loadSupportInfo failed – using defaults', e);
    }
  }

  Future<void> _loadReviewStatus() async {
    try {
      final sent = await _activationService.hasReviewBeenSent();
      if (mounted) setState(() => _reviewSent = sent);
    } catch (_) {
      if (mounted) setState(() => _reviewSent = false);
    }
  }


  String _formatExpiry(String? raw) {
    if (raw == null || raw.isEmpty) return 'غير محدد';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  String _planLabel(String? plan) {
    switch (plan) {
      case 'quarter_year':
        return '3 أشهر';
      case 'half_year':
        return '6 أشهر';
      case 'yearly':
        return 'سنة كاملة';
      default:
        return 'غير محدد';
    }
  }

  void _snack(String msg, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg, duration: const Duration(seconds: 3)),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChangeNotifierProvider.value(
      value: _ctrl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A1628) : const Color(0xFFEEF2F8),
        appBar: const CustomAppBar(
          title: 'الإعدادات',
          showNotifications: true,
          showSettings: false,
        ),
        body: Consumer<SettingsController>(
          builder: (context, ctrl, _) {
            if (ctrl.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }
            return RefreshIndicator(
              onRefresh: ctrl.load,
              color: AppTheme.primaryColor,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildProfileHeader(ctrl, isDark),
                  const SizedBox(height: 8),
                  _buildAccountSection(ctrl),
                  _buildSubscriptionSection(ctrl),
                  _buildOrdersSection(ctrl),
                  _buildDataSection(),
                  _buildUpdatesSection(),
                  _buildAppearanceSection(ctrl),
                  _buildPdfImportSection(),
                  if (!_reviewSent) _buildReviewSection(),
                  _buildSupportSection(ctrl),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🎨  PROFILE HEADER — Glassmorphism
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildProfileHeader(SettingsController ctrl, bool isDark) {
    final activated = ctrl.data.isActivated;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A4275), Color(0xFF0D2A50)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A4275).withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative circle top-right
            Positioned(
              top: -30, right: -30,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -40, left: -20,
              child: Container(
                width: 150, height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withValues(alpha: 0.15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                ctrl.data.agentName.isNotEmpty
                                    ? ctrl.data.agentName[0].toUpperCase()
                                    : 'م',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ctrl.data.agentName.isEmpty
                                  ? 'المندوب'
                                  : ctrl.data.agentName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (ctrl.data.agentPhone.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.phone_outlined,
                                      size: 13,
                                      color: Colors.white.withValues(alpha: 0.65)),
                                  const SizedBox(width: 4),
                                  Text(
                                    ctrl.data.agentPhone,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.75),
                                      fontSize: 13,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Edit button
                      GestureDetector(
                        onTap: () => _showEditAgentSheet(ctrl),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(Icons.edit_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Status strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _profileStat(
                          Icons.shield_outlined,
                          activated ? 'مفعّل ✓' : 'غير مفعّل',
                          activated ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                        Container(width: 1, height: 28,
                            color: Colors.white.withValues(alpha: 0.2)),
                        _profileStat(
                          Icons.workspace_premium_outlined,
                          _planLabel(ctrl.data.selectedPlan),
                          const Color(0xFFB8C4CE),
                        ),
                        Container(width: 1, height: 28,
                            color: Colors.white.withValues(alpha: 0.2)),
                        _profileStat(
                          Icons.event_outlined,
                          _formatExpiry(ctrl.data.expiresAt),
                          const Color(0xFFB8C4CE),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileStat(IconData icon, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1️⃣  ACCOUNT INFO
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildDeviceBindingInfoCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.blueGrey.shade900.withValues(alpha: 0.5)
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.blueGrey.shade700 : Colors.blue.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
              size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'هذا الحساب مرتبط بهذا الجهاز فقط ولا يمكن استخدامه على جهاز آخر.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: isDark ? Colors.blue.shade100 : Colors.blue.shade900,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(SettingsController ctrl) {
    final filled = ctrl.data.filledWarehouses;
    return SettingSection(
      title: 'معلومات الحساب',
      icon: Icons.person_outline,
      children: [
        _buildDeviceBindingInfoCard(),
        SettingTile(
          icon: Icons.badge_outlined,
          title: 'اسم المندوب',
          subtitle: ctrl.data.agentName.isEmpty ? 'لم يتم التعيين' : ctrl.data.agentName,
          onTap: () => _showEditAgentSheet(ctrl),
        ),
        SettingTile(
          icon: Icons.phone_outlined,
          title: 'رقم الهاتف',
          subtitle: ctrl.data.agentPhone.isEmpty ? 'لم يتم التعيين' : ctrl.data.agentPhone,
          onTap: () => _showEditAgentSheet(ctrl),
        ),
        SettingTile(
          icon: Icons.local_shipping_outlined,
          title: 'المستودعات',
          subtitle: filled.isEmpty
              ? 'لم تتم إضافة مستودعات'
              : filled.map((w) => w.name).join(' • '),
          onTap: () => _showManageWarehousesSheet(ctrl),
        ),
        SettingTile(
          icon: Icons.fingerprint,
          title: 'معرّف الجهاز',
          subtitle: ctrl.data.deviceId,
          showDivider: false,
          trailing: IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'نسخ',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: ctrl.data.deviceId));
              _snack('تم نسخ معرّف الجهاز');
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2️⃣  SUBSCRIPTION & ACTIVATION
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSubscriptionSection(SettingsController ctrl) {
    final activated = ctrl.data.isActivated;
    return SettingSection(
      title: 'الاشتراك والتفعيل',
      icon: Icons.verified_user_outlined,
      children: [
        SettingTile(
          icon: Icons.shield_outlined,
          iconColor: activated ? Colors.green : Colors.orange,
          title: 'حالة التفعيل',
          subtitle: activated ? 'مفعّل ✓' : 'غير مفعّل',
        ),
        SettingTile(
          icon: Icons.event_outlined,
          title: 'تاريخ الانتهاء',
          subtitle: _formatExpiry(ctrl.data.expiresAt),
        ),
        SettingTile(
          icon: Icons.workspace_premium_outlined,
          title: 'الباقة الحالية',
          subtitle: _planLabel(ctrl.data.selectedPlan),
        ),
        SettingTile(
          icon: Icons.sync_outlined,
          iconColor: Colors.blue,
          title: 'إعادة فحص التفعيل',
          subtitle: 'التحقق من حالة الاشتراك مع السيرفر',
          showDivider: false,
          trailing: _isCheckingActivation
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : null,
          onTap: _isCheckingActivation ? null : () => _recheckActivation(ctrl),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3️⃣  ORDERS & PDF
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildOrdersSection(SettingsController ctrl) {
    return SettingSection(
      title: 'الطلبيات والفواتير',
      icon: Icons.receipt_long_outlined,
      children: [
        // SettingTile(
        //   icon: Icons.text_fields_outlined,
        //   title: 'حجم خط PDF',
        //   subtitle: '${ctrl.data.pdfFontSize} نقطة',
        //   onTap: () => _showFontSizeSheet(ctrl),
        // ),
        // SettingTile(
        //   icon: Icons.card_giftcard_outlined,
        //   title: 'تفعيل الهدايا',
        //   subtitle: 'إظهار خانة الهدايا في الطلبيات',
        //   trailing: Switch.adaptive(
        //     value: ctrl.data.enableGifts,
        //     onChanged: (v) => ctrl.setEnableGifts(v),
        //   ),
        // ),
        SettingTile(
          icon: Icons.payments_outlined,
          title: 'تفعيل الأسعار',
          subtitle: ctrl.data.pricingEnabled
              ? (ctrl.data.currencyMode == 'usd' ? 'العملة: دولار \$' : 'العملة: ليرة سورية')
              : 'الأسعار معطّلة',
          showDivider: false,
          trailing: Switch.adaptive(
            value: ctrl.data.pricingEnabled,
            onChanged: (v) {
              ctrl.setPricingEnabled(v);
              if (v) _showPricingSheet(ctrl);
            },
          ),
          onTap: ctrl.data.pricingEnabled ? () => _showPricingSheet(ctrl) : null,
        ),
      ],
    );
  }


  // ═══════════════════════════════════════════════════════════════════
  // 4️⃣  DATA MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildDataSection() {
    return SettingSection(
      title: 'إدارة البيانات',
      icon: Icons.storage_outlined,
      children: [
        SettingTile(
          icon: Icons.cloud_upload_outlined,
          iconColor: Colors.grey,
          title: 'نسخ احتياطي',
          subtitle: 'قريباً — ستتوفر في تحديث قادم',
          enabled: false,
          onTap: () {},
        ),
        SettingTile(
          icon: Icons.file_upload_outlined,
          title: 'تصدير البيانات',
          subtitle: 'حفظ الشركات والأدوية كملف .smartagent',
          trailing: _isExporting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : null,
          onTap: _isExporting ? null : _exportData,
        ),
        SettingTile(
          icon: Icons.file_download_outlined,
          iconColor: Colors.green,
          title: 'استيراد البيانات',
          subtitle: 'استيراد الشركات والأدوية من ملف .smartagent',
          showDivider: false,
          trailing: _isImporting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : null,
          onTap: _isImporting ? null : _importData,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 5️⃣  UPDATES
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildUpdatesSection() {
    return SettingSection(
      title: 'التحديثات',
      icon: Icons.system_update_outlined,
      children: [
        SettingTile(
          icon: Icons.update_outlined,
          title: 'التحقق من التحديثات',
          subtitle: 'البحث عن إصدارات جديدة',
          trailing: _isCheckingUpdates
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : null,
          onTap: _isCheckingUpdates ? null : _checkForUpdates,
        ),
        SettingTile(
          icon: Icons.info_outline,
          title: 'الإصدار الحالي',
          subtitle: _appVersion.isEmpty ? 'جارٍ التحميل...' : _appVersion,
          showDivider: false,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 6️⃣  APPEARANCE
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildAppearanceSection(SettingsController ctrl) {
    return SettingSection(
      title: 'المظهر',
      icon: Icons.palette_outlined,
      children: [
        Consumer<ThemeProvider>(
          builder: (context, tp, _) {
            final label = tp.themeMode == ThemeMode.dark
                ? 'الوضع الداكن'
                : tp.themeMode == ThemeMode.light
                    ? 'الوضع الفاتح'
                    : 'تلقائي (حسب النظام)';
            return SettingTile(
              icon: tp.themeMode == ThemeMode.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              title: 'سمة التطبيق',
              subtitle: label,
              onTap: () => _showThemeSheet(tp),
            );
          },
        ),
        SettingTile(
          icon: Icons.view_carousel_outlined,
          title: 'إخفاء الإعلان الرئيسي',
          subtitle: 'إخفاء البانر من الصفحة الرئيسية',
          showDivider: false,
          trailing: Switch.adaptive(
            value: ctrl.data.hideCarousel,
            onChanged: (v) => ctrl.setHideCarousel(v),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 7️⃣  SUPPORT
  // ═══════════════════════════════════════════════════════════════════
    Widget _buildSupportSection(SettingsController ctrl) {
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
                      child: Text(
                        '$unread',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
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
            messageTemplate: _buildSupportMessageTemplate(ctrl),
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
            messageTemplate: _buildFeatureRequestMessageTemplate(ctrl),
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

  // ═══════════════════════════════════════════════════════════════════
  //  BOTTOM SHEETS & DIALOGS
  // ═══════════════════════════════════════════════════════════════════

  /// Edit Agent Info (name + phone only)
  void _showEditAgentSheet(SettingsController ctrl) {
    final nameC = TextEditingController(text: ctrl.data.agentName);
    final phoneC = TextEditingController(text: ctrl.data.agentPhone);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
              Text('تعديل بيانات المندوب',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildTextField(nameC, 'الاسم الكامل', Icons.person_outline, validator: (v) {
                if (v == null || v.trim().isEmpty) return 'مطلوب';
                if (v.trim().length < 3) return 'الاسم يجب أن يكون 3 أحرف على الأقل';
                return null;
              }),
              const SizedBox(height: 14),
              _buildTextField(phoneC, 'رقم الهاتف', Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) => validatePhone(v, required: true)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
                child: ListenableBuilder(
                  listenable: ctrl,
                  builder: (_, __) => FilledButton(
                    onPressed: ctrl.isSavingAccount ? null : () async {
                      if (!formKey.currentState!.validate()) return;
                      final name = nameC.text.trim();
                      final phone = phoneC.text.trim();
                      Navigator.pop(ctx);
                      final ok = await ctrl.saveAccount(name, phone);
                      _snack(ok ? 'تم الحفظ بنجاح وتحديث السيرفر' : 'تم الحفظ محلياً (السيرفر غير متاح)',
                        bg: ok ? Colors.green : Colors.orange);
                    },
                    child: ctrl.isSavingAccount
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('حفظ التعديلات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameC.dispose();
        phoneC.dispose();
      });
    });
  }

  /// Manage Warehouses (up to 4, each with name + phone)
  void _showManageWarehousesSheet(SettingsController ctrl) {
    final max = SettingsService.maxWarehouses;
    final nameControllers = <TextEditingController>[];
    final phoneControllers = <TextEditingController>[];
    for (int i = 0; i < max; i++) {
      final w = i < ctrl.data.warehouses.length ? ctrl.data.warehouses[i] : const Warehouse();
      nameControllers.add(TextEditingController(text: w.name));
      phoneControllers.add(TextEditingController(text: w.phone));
    }
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Check sequential fill state
            bool isSlotEnabled(int index) {
              if (index == 0) return true;
              for (int j = 0; j < index; j++) {
                if (nameControllers[j].text.trim().isEmpty || phoneControllers[j].text.trim().isEmpty) {
                  return false;
                }
              }
              return true;
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                      Text('إدارة المستودعات',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('أضف حتى $max مستودعات — كل مستودع باسمه ورقم واتساب',
                        style: Theme.of(context).textTheme.bodySmall, textDirection: TextDirection.rtl),
                      const SizedBox(height: 16),
                      for (int i = 0; i < max; i++) ...[
                        if (i > 0) const Divider(height: 24),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Text('مستودع ${i + 1}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            textDirection: TextDirection.rtl),
                        ),
                        const SizedBox(height: 8),
                        _buildTextField(nameControllers[i], 'اسم المستودع', Icons.label_outline,
                          enabled: isSlotEnabled(i),
                          onChanged: (_) => setSheetState(() {})),
                        const SizedBox(height: 8),
                        _buildTextField(phoneControllers[i], 'رقم واتساب', Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          enabled: isSlotEnabled(i),
                          validator: (v) => validatePhone(v, required: false),
                          onChanged: (_) => setSheetState(() {})),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final list = <Warehouse>[];
                            for (int i = 0; i < max; i++) {
                              final n = nameControllers[i].text.trim();
                              final p = phoneControllers[i].text.trim();
                              // Enforce sequential: if previous is empty, clear this
                              if (i > 0 && list[i - 1].isEmpty) {
                                list.add(const Warehouse());
                              } else {
                                list.add(Warehouse(name: n, phone: p));
                              }
                            }
                            Navigator.pop(ctx);
                            await ctrl.saveWarehouses(list);
                            _snack('تم حفظ المستودعات', bg: Colors.green);
                          },
                          child: const Text('حفظ المستودعات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final c in nameControllers) { c.dispose(); }
        for (final c in phoneControllers) { c.dispose(); }
      });
    });
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: TextDirection.rtl,
      validator: validator,
      enabled: enabled,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: enabled
            ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
      ),
    );
  }


  /// Pricing Sheet
  void _showPricingSheet(SettingsController ctrl) {
    String mode = ctrl.data.currencyMode;
    final rateC = TextEditingController(text: ctrl.data.exchangeRate.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
              ),
              Text('إعدادات الأسعار',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _currencyOption(ctx, setLocal, mode, 'usd', 'الدولار  \$', Icons.attach_money,
                  (v) => setLocal(() => mode = v)),
              const SizedBox(height: 10),
              _currencyOption(ctx, setLocal, mode, 'syp', 'الليرة السورية', Icons.money,
                  (v) => setLocal(() => mode = v)),
              if (mode == 'syp') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: rateC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: 'سعر صرف الدولار',
                    prefixIcon: const Icon(Icons.currency_exchange),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    ctrl.setCurrencyMode(mode);
                    if (mode == 'syp') {
                      final rate = double.tryParse(rateC.text.trim());
                      if (rate != null && rate > 0) ctrl.setExchangeRate(rate);
                    }
                    Navigator.pop(ctx);
                    _snack('تم حفظ إعدادات الأسعار', bg: Colors.green);
                  },
                  child: const Text('حفظ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _currencyOption(
    BuildContext ctx,
    StateSetter setLocal,
    String current,
    String value,
    String label,
    IconData icon,
    ValueChanged<String> onTap,
  ) {
    final selected = current == value;
    final theme = Theme.of(ctx);
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          color: selected ? theme.colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? theme.colorScheme.primary : Colors.grey),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? theme.colorScheme.primary : null,
                )),
            const Spacer(),
            if (selected) Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  /// Theme Sheet
  void _showThemeSheet(ThemeProvider tp) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
              ),
              Text('اختر سمة التطبيق',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _themeChoice(ctx, tp, ThemeMode.light, 'فاتح', Icons.light_mode_outlined),
              const SizedBox(height: 10),
              _themeChoice(ctx, tp, ThemeMode.dark, 'داكن', Icons.dark_mode_outlined),
              const SizedBox(height: 10),
              _themeChoice(ctx, tp, ThemeMode.system, 'تلقائي', Icons.brightness_auto_outlined),
            ],
          ),
        );
      },
    );
  }

  Widget _themeChoice(BuildContext ctx, ThemeProvider tp, ThemeMode mode, String label, IconData icon) {
    final selected = tp.themeMode == mode;
    final theme = Theme.of(ctx);
    return GestureDetector(
      onTap: () {
        tp.setThemeMode(mode);
        Navigator.pop(ctx);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          color: selected ? theme.colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? theme.colorScheme.primary : Colors.grey),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? theme.colorScheme.primary : null,
                )),
            const Spacer(),
            if (selected) Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _recheckActivation(SettingsController ctrl) async {
    setState(() => _isCheckingActivation = true);
    try {
      final verified = await ctrl.recheckActivation();
      if (!mounted) return;
      // Show result in-place — do NOT navigate away.
      // The user initiated the recheck from inside the app (Settings screen),
      // so they should stay exactly where they are after seeing the result.
      await showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(verified ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: verified ? Colors.green : Colors.orange, size: 28),
              const SizedBox(width: 8),
              Text(verified ? 'مفعّل ✓' : 'غير مفعّل', textDirection: TextDirection.rtl),
            ],
          ),
          content: Text(
            verified
                ? 'تم التحقق بنجاح. التطبيق مفعّل.'
                : 'التطبيق غير مفعّل حالياً. يرجى التواصل مع خدمة العملاء أو اختيار باقة اشتراك.',
            textDirection: TextDirection.rtl,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            // Use dialogCtx so we close only the dialog, not the settings screen.
            FilledButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('حسناً')),
          ],
        ),
      );
      // Stay on Settings — no pushNamedAndRemoveUntil here.
    } catch (e) {
      AppLogger.e('SettingsScreen', '_recheckActivation failed', e);
      if (!mounted) return;
      _snack('تعذر الاتصال بالسيرفر: ${e.toString()}', bg: Colors.red);
    } finally {
      if (mounted) setState(() => _isCheckingActivation = false);
    }
  }

  Future<void> _exportData() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final file = await _dataExport.exportData();
      await _dataExport.shareFile(file);
      _snack('تم التصدير بنجاح', bg: Colors.green);
    } catch (e) {
      AppLogger.e('SettingsScreen', '_exportData failed', e);
      if (e.toString().contains('OFFLINE_LIMIT_EXCEEDED') && mounted) {
        Navigator.of(context).pushReplacementNamed('/offline-limit');
        return;
      }
      _snack('خطأ في التصدير: ${e.toString()}', bg: Colors.red);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importData() async {
    if (_isImporting) return;
    try {
      // ── File picker strategy ──────────────────────────────────────────
      // Android's system file picker (ACTION_OPEN_DOCUMENT) filters by MIME
      // type, NOT by file extension.  .smartagent has no registered MIME type
      // in Android's MimeTypeMap, so FileType.custom with ['smartagent'] would
      // produce an empty MIME list → PlatformException.
      //
      // Workaround: use FileType.custom with extensions that DO resolve to
      // useful MIME types.  Unknown-extension files (like .smartagent) are
      // typically classified as application/octet-stream by Android file
      // managers, so including 'bin' (which maps to application/octet-stream)
      // makes .smartagent files selectable while graying out images, videos,
      // PDFs, etc.
      //
      // If the device's file manager doesn't support the custom filter at all,
      // we catch the PlatformException and fall back to FileType.any.
      //
      // Either way, we always validate the extension after selection.
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          // 'bin' → application/octet-stream  (matches .smartagent on most file managers)
          // 'json' → application/json
          allowedExtensions: ['bin', 'json'],
          dialogTitle: 'اختر ملف .smartagent',
          withData: true,
        );
      } on PlatformException {
        // Fallback: if the device can't handle the custom filter, show all files.
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          dialogTitle: 'اختر ملف .smartagent',
          withData: true,
        );
      }
      if (result == null || result.files.single.bytes == null) return;

      final fileName = result.files.single.name;
      final bytes = result.files.single.bytes!;

      // ── Extension whitelist ────────────────────────────────────────────
      // Accept only .smartagent and .json; reject everything else immediately.
      const allowedExts = {'.smartagent', '.json'};
      final ext = fileName.contains('.')
          ? '.${fileName.split('.').last.toLowerCase()}'
          : '';
      if (!allowedExts.contains(ext)) {
        _snack(
          'الملف المحدد غير مدعوم.\n'
          'يُرجى اختيار ملف بامتداد .smartagent فقط.',
          bg: Colors.red,
        );
        return;
      }

      // Validate file content
      try {
        final decoded = utf8.decode(bytes);
        final data = jsonDecode(decoded) as Map<String, dynamic>;
        if (!data.containsKey('companies') || !data.containsKey('medicines')) {
          _snack('الملف غير صالح: لا يحتوي على بيانات شركات أو أدوية', bg: Colors.red);
          return;
        }
      } catch (e) {
        AppLogger.w('SettingsScreen', 'import file decode/validation failed', e);
        _snack('الملف تالف أو غير صالح. تأكد من أنه ملف بيانات المندوب الذكي.', bg: Colors.red);
        return;
      }

      // Show confirmation dialog
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.file_present_rounded, size: 48, color: Colors.blueAccent),
          title: const Text('استيراد بيانات', textDirection: TextDirection.rtl),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('هل تريد استيراد البيانات من هذا الملف؟',
                  textAlign: TextAlign.center, textDirection: TextDirection.rtl),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insert_drive_file_rounded, size: 18, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(fileName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيتم إضافة الشركات والأدوية الجديدة فقط.\nالبيانات المتكررة لن تُستورد.',
                        style: TextStyle(fontSize: 12),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('إلغاء'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogCtx, true),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('استيراد'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() => _isImporting = true);
      final importResult = await _dataExport.importData(bytes);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('تم الاستيراد بنجاح', textDirection: TextDirection.rtl),
            ],
          ),
          content: Text(
            'الشركات: ${importResult.companiesAdded} أُضيفت، ${importResult.companiesSkipped} تم تخطيها\n'
            'الأدوية: ${importResult.medicinesAdded} أُضيفت، ${importResult.medicinesSkipped} تم تخطيها',
            textDirection: TextDirection.rtl,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
          ],
        ),
      );
    } catch (e) {
      AppLogger.e('SettingsScreen', '_importData failed', e);
      _snack('خطأ في الاستيراد: ${e.toString()}', bg: Colors.red);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdates) return;
    setState(() => _isCheckingUpdates = true);
    try {
      final pkg = await PackageInfo.fromPlatform();
      final info = await UpdateService().checkForUpdate(pkg.version);
      if (!mounted) return;
      if (info != null) {
        showUpdateDialog(context, info);
        await _loadSupportInfo();
      } else {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: const Text('لا يوجد تحديث جديد حالياً.', textDirection: TextDirection.rtl),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
            ],
          ),
        );
      }
    } catch (e) {
      AppLogger.e('SettingsScreen', '_checkForUpdates failed', e);
      _snack('خطأ في التحقق من التحديث: ${e.toString()}', bg: Colors.red);
    } finally {
      if (mounted) setState(() => _isCheckingUpdates = false);
    }
  }

  String _buildSupportMessageTemplate(SettingsController ctrl) {
    return '''مرحباً،
لدي استفسار/مشكلة بخصوص تطبيق المندوب الذكي.

تفاصيل الطلب:

---
اسم المندوب: ${ctrl.data.agentName}
رقم الهاتف: ${ctrl.data.agentPhone}
معرّف الجهاز: ${ctrl.data.deviceId}
إصدار التطبيق: $_appVersion
---''';
  }

  String _buildFeatureRequestMessageTemplate(SettingsController ctrl) {
    return '''مرحباً،
لدي اقتراح ميزة جديدة لتطبيق المندوب الذكي.

اسم الميزة:
وصف مختصر:
الفائدة المتوقعة:

---
اسم المندوب: ${ctrl.data.agentName}
رقم الهاتف: ${ctrl.data.agentPhone}
معرّف الجهاز: ${ctrl.data.deviceId}
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
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Text(
              actionTitle,
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 6),
            Text(
              'اختر طريقة التواصل المناسبة',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 14),
            _buildContactMethodTile(
              ctx: ctx,
              icon: Icons.email_outlined,
              title: 'البريد الإلكتروني',
              subtitle: _support.email,
              color: Colors.blue,
              onTap: () async {
                Navigator.pop(ctx);
                await _launchSupportByEmail(emailSubject, messageTemplate);
              },
            ),
            const SizedBox(height: 10),
            _buildContactMethodTile(
              ctx: ctx,
              icon: Icons.telegram,
              title: 'تلجرام',
              subtitle: _support.telegram,
              color: const Color(0xFF0088CC),
              onTap: () async {
                Navigator.pop(ctx);
                await _launchSupportByTelegram(messageTemplate);
              },
            ),
            const SizedBox(height: 10),
            _buildContactMethodTile(
              ctx: ctx,
              icon: Icons.chat_outlined,
              title: 'واتساب',
              subtitle: _support.whatsapp,
              color: Colors.green,
              onTap: () async {
                Navigator.pop(ctx);
                await _launchSupportByWhatsApp(messageTemplate);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactMethodTile({
    required BuildContext ctx,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Future<void> Function() onTap,
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                      textDirection: TextDirection.rtl,
                    ),
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

  Future<void> _launchSupportByEmail(String subject, String message) async {
    await _launchSupportMethod(
      method: ContactMethodType.email,
      message: message,
      emailSubject: subject,
    );
  }

  Future<void> _launchSupportByTelegram(String message) async {
    await _launchSupportMethod(
      method: ContactMethodType.telegram,
      message: message,
    );
  }

  Future<void> _launchSupportByWhatsApp(String message) async {
    await _launchSupportMethod(
      method: ContactMethodType.whatsapp,
      message: message,
    );
  }

  Future<void> _launchSupportMethod({
    required ContactMethodType method,
    required String message,
    String? emailSubject,
  }) async {
    final result = await _contactLauncher.launch(
      method: method,
      support: _support,
      message: message,
      emailSubject: emailSubject,
    );
    if (!mounted || result.success) return;
    _contactLauncher.showLaunchError(
      context,
      method: method,
      result: result,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PDF IMPORT INSTRUCTIONS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildPdfImportSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const pdfMessage =
        'يمكنك إرسال ملف PDF الخاص بالمستودع عبر واتساب أو تيليجرام، وسيتم تحويله إلى ملف قابل للاستيراد داخل التطبيق (.smartagent) خلال 24-48 ساعة.';
    const pdfWhatsAppMsg =
        'مرحباً، أرغب في تحويل ملف PDF الخاص بالمستودع إلى ملف .smartagent.';

    return SettingSection(
      title: 'استيراد الأدوية من ملف PDF',
      icon: Icons.picture_as_pdf_outlined,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.blue.shade900.withValues(alpha: 0.18)
                : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.blue.shade800 : Colors.blue.shade200,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                  size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pdfMessage,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: isDark
                        ? Colors.blue.shade100
                        : Colors.blue.shade900,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SettingTile(
          icon: Icons.chat_outlined,
          iconColor: Colors.green,
          title: 'إرسال عبر واتساب',
          subtitle: _support.whatsapp,
          onTap: () => _launchSupportByWhatsApp(pdfWhatsAppMsg),
        ),
        SettingTile(
          icon: Icons.telegram,
          iconColor: const Color(0xFF0088CC),
          title: 'إرسال عبر تيليجرام',
          subtitle: _support.telegram,
          showDivider: false,
          onTap: () => _launchSupportByTelegram(pdfWhatsAppMsg),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // REVIEW SECTION
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildReviewSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SettingSection(
      title: 'قيّم التطبيق',
      icon: Icons.star_outline_rounded,
      children: [
        // Stars row
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
                    starIndex <= _reviewStars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
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
        // Comment field
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
            fillColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
          ),
        ),
        if (_reviewError != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _reviewError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: FilledButton.icon(
            onPressed: (_isSubmittingReview || _reviewStars == 0)
                ? null
                : _submitReview,
            icon: _isSubmittingReview
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
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

  Future<void> _submitReview() async {
    if (_reviewStars == 0) return;
    setState(() {
      _isSubmittingReview = true;
      _reviewError = null;
    });
    try {
      final success = await _activationService.submitReview(
        stars: _reviewStars,
        comment: _reviewCommentController.text.trim().isEmpty
            ? null
            : _reviewCommentController.text.trim(),
      );
      if (!mounted) return;
      if (success) {
        await _activationService.markReviewSent();
        if (mounted) {
          setState(() {
            _reviewSent = true;
            _isSubmittingReview = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('شكراً! تم إرسال تقييمك بنجاح.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _isSubmittingReview = false;
          _reviewError = 'فشل الإرسال. يرجى المحاولة مجدداً.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmittingReview = false;
        _reviewError = 'حدث خطأ: ${e.toString()}';
      });
    }
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
        const Text(
          'تطبيق لإدارة الطلبيات والفواتير محلياً بدون الحاجة للإنترنت.',
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }
}
