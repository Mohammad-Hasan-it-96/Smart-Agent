import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/update_service.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/update_dialog.dart';
import '../../../core/utils/app_logger.dart';
import '../settings_controller.dart';
import '../widgets/setting_tile.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  late final SettingsController _ctrl;
  String _appVersion = '';
  bool _isCheckingUpdates = false;

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
    } catch (e) {
      if (mounted) setState(() => _appVersion = '1.0.0');
    }
  }

  void _snack(String msg, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg, duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChangeNotifierProvider.value(
      value: _ctrl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A1628) : const Color(0xFFEEF2F8),
        appBar: const CustomAppBar(
          title: 'التطبيق والتحديثات',
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
                _buildUpdatesSection(),
                _buildAppearanceSection(ctrl),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

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

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdates) return;
    setState(() => _isCheckingUpdates = true);
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
      AppLogger.e('AppSettingsPage', '_checkForUpdates failed', e);
      _snack('خطأ في التحقق من التحديث: ${e.toString()}', bg: Colors.red);
    } finally {
      if (mounted) setState(() => _isCheckingUpdates = false);
    }
  }

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
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
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
}

