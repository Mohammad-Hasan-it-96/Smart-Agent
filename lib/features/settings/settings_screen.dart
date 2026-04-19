import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/widgets/custom_app_bar.dart';
import 'settings_controller.dart';
import 'pages/account_settings_page.dart';
import 'pages/data_settings_page.dart';
import 'pages/app_settings_page.dart';
import 'pages/support_settings_page.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _ctrl;
  String _appVersion = '';

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

  String _buildAccountSubtitle(SettingsController ctrl) {
    final parts = <String>[];
    if (ctrl.data.agentName.isNotEmpty) parts.add(ctrl.data.agentName);
    parts.add(ctrl.data.isActivated ? 'مفعّل ✓' : 'غير مفعّل');
    return parts.join(' • ');
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    ).then((_) => _ctrl.load());
  }

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
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
            }
            return RefreshIndicator(
              onRefresh: ctrl.load,
              color: AppTheme.primaryColor,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildProfileHeader(ctrl, isDark),
                  const SizedBox(height: 16),
                  _buildCategoryCard(
                    icon: Icons.person_outline_rounded,
                    color: Colors.blue,
                    title: 'الحساب والمندوب',
                    subtitle: _buildAccountSubtitle(ctrl),
                    onTap: () => _openPage(const AccountSettingsPage()),
                  ),
                  _buildCategoryCard(
                    icon: Icons.folder_outlined,
                    color: Colors.teal,
                    title: 'البيانات والملفات',
                    subtitle: 'تصدير واستيراد البيانات ومشاركة التطبيق',
                    onTap: () => _openPage(const DataSettingsPage()),
                  ),
                  _buildCategoryCard(
                    icon: Icons.system_update_outlined,
                    color: Colors.deepPurple,
                    title: 'التطبيق والتحديثات',
                    subtitle: 'الإصدار $_appVersion',
                    onTap: () => _openPage(const AppSettingsPage()),
                  ),
                  _buildCategoryCard(
                    icon: Icons.support_agent_outlined,
                    color: Colors.orange,
                    title: 'الدعم والتواصل',
                    subtitle: 'تواصل معنا أو قيّم التطبيق',
                    onTap: () => _openPage(const SupportSettingsPage()),
                    trailing: ValueListenableBuilder<int>(
                      valueListenable: PushNotificationService.instance.unreadCount,
                      builder: (_, unread, __) {
                        if (unread == 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('$unread',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700, height: 1.3)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600], height: 1.3),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
                Icon(Icons.chevron_left, size: 22,
                  color: isDark ? Colors.grey[500] : Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
            Positioned(top: -30, right: -30,
              child: Container(width: 120, height: 120,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)))),
            Positioned(bottom: -40, left: -20,
              child: Container(width: 150, height: 150,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.04)))),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withValues(alpha: 0.15),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                ctrl.data.agentName.isNotEmpty ? ctrl.data.agentName[0].toUpperCase() : 'م',
                                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ctrl.data.agentName.isEmpty ? 'المندوب' : ctrl.data.agentName,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (ctrl.data.agentPhone.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(children: [
                                Icon(Icons.phone_outlined, size: 13, color: Colors.white.withValues(alpha: 0.65)),
                                const SizedBox(width: 4),
                                Text(ctrl.data.agentPhone,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, fontFamily: 'Cairo')),
                              ]),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _profileStat(Icons.shield_outlined, activated ? 'مفعّل ✓' : 'غير مفعّل',
                          activated ? Colors.greenAccent : Colors.orangeAccent),
                        Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.2)),
                        _profileStat(Icons.workspace_premium_outlined, _planLabel(ctrl.data.selectedPlan), const Color(0xFFB8C4CE)),
                        Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.2)),
                        _profileStat(Icons.event_outlined, _formatExpiry(ctrl.data.expiresAt), const Color(0xFFB8C4CE)),
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
        Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
      ],
    );
  }
}

