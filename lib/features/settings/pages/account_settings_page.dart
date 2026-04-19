import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/warehouse.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/phone_validator.dart';
import '../../../core/services/settings_service.dart';
import '../settings_controller.dart';
import '../widgets/setting_tile.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  late final SettingsController _ctrl;
  bool _isCheckingActivation = false;

  @override
  void initState() {
    super.initState();
    _ctrl = SettingsController();
    _ctrl.load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg, duration: const Duration(seconds: 3)),
    );
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChangeNotifierProvider.value(
      value: _ctrl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A1628) : const Color(0xFFEEF2F8),
        appBar: const CustomAppBar(
          title: 'الحساب والمندوب',
          showNotifications: false,
          showSettings: false,
        ),
        body: Consumer<SettingsController>(
          builder: (context, ctrl, _) {
            if (ctrl.isLoading) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
            }
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildAccountSection(ctrl),
                _buildSubscriptionSection(ctrl),
                _buildOrdersSection(ctrl),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Account Info ──
  Widget _buildAccountSection(SettingsController ctrl) {
    final filled = ctrl.data.filledWarehouses;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SettingSection(
      title: 'معلومات الحساب',
      icon: Icons.person_outline,
      children: [
        _buildDeviceBindingInfoCard(isDark),
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

  Widget _buildDeviceBindingInfoCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.blueGrey.shade900.withValues(alpha: 0.5) : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.blueGrey.shade700 : Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: isDark ? Colors.blue.shade200 : Colors.blue.shade700, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'هذا الحساب مرتبط بهذا الجهاز فقط ولا يمكن استخدامه على جهاز آخر.',
              style: TextStyle(
                fontSize: 13.5, height: 1.5,
                color: isDark ? Colors.blue.shade100 : Colors.blue.shade900,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  // ── Subscription ──
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

  // ── Orders & Pricing ──
  Widget _buildOrdersSection(SettingsController ctrl) {
    return SettingSection(
      title: 'الطلبيات والفواتير',
      icon: Icons.receipt_long_outlined,
      children: [
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

  // ── Sheets ──
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

  void _showManageWarehousesSheet(SettingsController ctrl) {
    const max = SettingsService.maxWarehouses;
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
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
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
                width: double.infinity, height: 52,
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

  Widget _currencyOption(BuildContext ctx, StateSetter setLocal, String current, String value,
      String label, IconData icon, ValueChanged<String> onTap) {
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
            Text(label, style: TextStyle(
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

  Future<void> _recheckActivation(SettingsController ctrl) async {
    setState(() => _isCheckingActivation = true);
    try {
      final verified = await ctrl.recheckActivation();
      if (!mounted) return;
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
            FilledButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('حسناً')),
          ],
        ),
      );
    } catch (e) {
      AppLogger.e('AccountSettingsPage', '_recheckActivation failed', e);
      if (!mounted) return;
      _snack('تعذر الاتصال بالسيرفر: ${e.toString()}', bg: Colors.red);
    } finally {
      if (mounted) setState(() => _isCheckingActivation = false);
    }
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
}

