import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/data_export_service.dart';
import '../../core/services/update_service.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/update_dialog.dart';
import 'settings_controller.dart';
import 'widgets/setting_tile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _ctrl;
  final _dataExport = DataExportService();
  String _appVersion = '';
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isCheckingActivation = false;

  @override
  void initState() {
    super.initState();
    _ctrl = SettingsController();
    _ctrl.load();
    _loadVersion();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    } catch (_) {
      if (mounted) setState(() => _appVersion = '1.0.0');
    }
  }

  // ─── HELPERS ──────────────────────────────────────────────────────

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
      case '3_months':
        return '3 أشهر';
      case '6_months':
        return '6 أشهر';
      case '12_months':
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
    return ChangeNotifierProvider.value(
      value: _ctrl,
      child: Scaffold(
        appBar: const CustomAppBar(title: 'الإعدادات'),
        body: Consumer<SettingsController>(
          builder: (context, ctrl, _) {
            if (ctrl.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: ctrl.load,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildAccountSection(ctrl),
                  _buildSubscriptionSection(ctrl),
                  _buildOrdersSection(ctrl),
                  _buildDataSection(),
                  _buildUpdatesSection(),
                  _buildAppearanceSection(ctrl),
                  _buildSupportSection(),
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
  // 1️⃣  ACCOUNT INFO
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildAccountSection(SettingsController ctrl) {
    return SettingSection(
      title: 'معلومات الحساب',
      icon: Icons.person_outline,
      children: [
        SettingTile(
          icon: Icons.badge_outlined,
          title: 'اسم المندوب',
          subtitle: ctrl.data.agentName.isEmpty ? 'لم يتم التعيين' : ctrl.data.agentName,
          onTap: () => _showEditAccountSheet(ctrl),
        ),
        SettingTile(
          icon: Icons.phone_outlined,
          title: 'رقم الهاتف',
          subtitle: ctrl.data.agentPhone.isEmpty ? 'لم يتم التعيين' : ctrl.data.agentPhone,
          onTap: () => _showEditAccountSheet(ctrl),
        ),
        SettingTile(
          icon: Icons.warehouse_outlined,
          title: 'رقم المستودع',
          subtitle: ctrl.data.inventoryPhone.isEmpty ? 'لم يتم التعيين' : ctrl.data.inventoryPhone,
          onTap: () => _showEditAccountSheet(ctrl),
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
          subtitle: 'حفظ الشركات والأدوية كملف JSON',
          trailing: _isExporting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : null,
          onTap: _isExporting ? null : _exportData,
        ),
        SettingTile(
          icon: Icons.file_download_outlined,
          iconColor: Colors.green,
          title: 'استيراد البيانات',
          subtitle: 'استيراد الشركات والأدوية من ملف JSON',
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
          onTap: _checkForUpdates,
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
  Widget _buildSupportSection() {
    return SettingSection(
      title: 'الدعم والمساعدة',
      icon: Icons.support_agent_outlined,
      children: [
        SettingTile(
          icon: Icons.email_outlined,
          title: 'البريد الإلكتروني',
          subtitle: 'smartAgentAppSupport@gmail.com',
          onTap: _openSupportEmail,
        ),
        SettingTile(
          icon: Icons.telegram,
          iconColor: const Color(0xFF0088CC),
          title: 'تلجرام',
          subtitle: 'تواصل عبر تلجرام',
          onTap: _openTelegram,
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

  /// Edit Account Info
  void _showEditAccountSheet(SettingsController ctrl) {
    final nameC = TextEditingController(text: ctrl.data.agentName);
    final phoneC = TextEditingController(text: ctrl.data.agentPhone);
    final invC = TextEditingController(text: ctrl.data.inventoryPhone);
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
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'تعديل بيانات المندوب',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildTextField(nameC, 'الاسم الكامل', Icons.person_outline, validator: (v) {
                if (v == null || v.trim().isEmpty) return 'مطلوب';
                if (v.trim().length < 3) return 'الاسم يجب أن يكون 3 أحرف على الأقل';
                return null;
              }),
              const SizedBox(height: 14),
              _buildTextField(phoneC, 'رقم الهاتف', Icons.phone_outlined,
                  keyboardType: TextInputType.phone, validator: (v) {
                if (v == null || v.trim().isEmpty) return 'مطلوب';
                final clean = v.trim().replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
                if (!RegExp(r'^[0-9]{8,}$').hasMatch(clean)) return 'رقم هاتف غير صالح';
                return null;
              }),
              const SizedBox(height: 14),
              _buildTextField(invC, 'رقم المستودع (واتساب)', Icons.warehouse_outlined,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ListenableBuilder(
                  listenable: ctrl,
                  builder: (_, __) => FilledButton(
                    onPressed: ctrl.isSavingAccount
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            final ok = await ctrl.saveAccount(
                              nameC.text.trim(),
                              phoneC.text.trim(),
                              invC.text.trim(),
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            _snack(
                              ok ? 'تم الحفظ بنجاح وتحديث السيرفر' : 'تم الحفظ محلياً (السيرفر غير متاح)',
                              bg: ok ? Colors.green : Colors.orange,
                            );
                          },
                    child: ctrl.isSavingAccount
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('حفظ التعديلات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: TextDirection.rtl,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
    );
  }

  /// Font Size Sheet
  void _showFontSizeSheet(SettingsController ctrl) {
    int size = ctrl.data.pdfFontSize;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
              ),
              Text('حجم خط PDF', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Text('$size نقطة', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Slider(
                value: size.toDouble(),
                min: 8,
                max: 24,
                divisions: 16,
                label: '$size',
                onChanged: (v) => setLocal(() => size = v.toInt()),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    ctrl.setPdfFontSize(size);
                    Navigator.pop(ctx);
                    _snack('تم حفظ حجم الخط', bg: Colors.green);
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
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
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
                : 'التطبيق غير مفعّل حالياً. يرجى التواصل مع المطور أو اختيار باقة اشتراك.',
            textDirection: TextDirection.rtl,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
          ],
        ),
      );
    } catch (e) {
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;

      setState(() => _isImporting = true);
      final importResult = await _dataExport.importData(result.files.single.bytes!);
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
      _snack('خطأ في الاستيراد: ${e.toString()}', bg: Colors.red);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final info = await UpdateService().checkForUpdate(pkg.version);
      if (!mounted) return;
      if (info != null) {
        showUpdateDialog(context, info);
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
      _snack('خطأ في التحقق من التحديث: ${e.toString()}', bg: Colors.red);
    }
  }

  Future<void> _openSupportEmail() async {
    const email = 'smartAgentAppSupport@gmail.com';
    try {
      final launched = await launchUrl(Uri.parse('mailto:$email'), mode: LaunchMode.externalApplication);
      if (!launched && mounted) _showCopyFallback(email, 'البريد الإلكتروني');
    } catch (_) {
      if (mounted) _showCopyFallback(email, 'البريد الإلكتروني');
    }
  }

  Future<void> _openTelegram() async {
    const url = 'https://t.me/+963983820430';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      _showCopyFallback('+963983820430', 'تلجرام');
    }
  }

  void _showCopyFallback(String text, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label: $text'),
        action: SnackBarAction(
          label: 'نسخ',
          onPressed: () => Clipboard.setData(ClipboardData(text: text)),
        ),
      ),
    );
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
