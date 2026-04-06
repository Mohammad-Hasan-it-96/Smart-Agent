import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/push_notification_service.dart';
import '../theme/app_theme.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final bool showThemeToggle;

  /// Show a notifications bell.
  /// • When [automaticallyImplyLeading] is false (root screens) → placed in
  ///   leading (right side in RTL).
  /// • When the screen has a back button → placed as the first action item.
  final bool showNotifications;

  /// Show a settings gear icon in the action bar (before the theme toggle).
  /// Should be false on the settings screen itself.
  final bool showSettings;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.showThemeToggle = true,
    this.showNotifications = false,
    this.showSettings = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // For root screens (no back button): place notifications bell in leading
    // so it appears on the RIGHT in RTL.
    final Widget? leadingWidget =
        (showNotifications && !automaticallyImplyLeading)
            ? _buildNotificationsBell(context, isDark)
            : null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F2040) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppBar(
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.primaryColor,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: automaticallyImplyLeading,
        leading: leadingWidget,
        actions: _buildActions(context, isDark),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : AppTheme.primaryColor,
        // Custom back button style
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : AppTheme.primaryColor,
        ),
      ),
    );
  }

  // ── Notifications bell widget ──────────────────────────────────────
  Widget _buildNotificationsBell(BuildContext context, bool isDark) {
    return ValueListenableBuilder<int>(
      valueListenable: PushNotificationService.instance.unreadCount,
      builder: (context, count, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'الإشعارات',
              onPressed: () =>
                  Navigator.pushNamed(context, '/notifications'),
              icon: Icon(
                count > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_none_rounded,
                color: isDark ? Colors.white : AppTheme.primaryColor,
              ),
            ),
            if (count > 0)
              Positioned(
                top: 8,
                left: 8,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF0F2040) : Colors.white,
                        width: 1.5,
                      ),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Actions list ───────────────────────────────────────────────────
  List<Widget>? _buildActions(BuildContext context, bool isDark) {
    final List<Widget> result = [];

    // 1. Notifications bell for screens that HAVE a back button
    if (showNotifications && automaticallyImplyLeading) {
      result.add(_buildNotificationsBell(context, isDark));
    }

    // 2. Custom actions (e.g. trial badge)
    if (actions != null) {
      result.addAll(actions!);
    }

    // 3. Settings shortcut
    if (showSettings) {
      result.add(
        IconButton(
          tooltip: 'الإعدادات',
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          icon: Icon(
            Icons.settings_outlined,
            color: isDark ? Colors.white : AppTheme.primaryColor,
          ),
        ),
      );
    }

    // 4. Theme toggle (always last)
    if (showThemeToggle) {
      result.add(
        Consumer<ThemeProvider>(
          builder: (context, tp, _) {
            final icon = switch (tp.themeMode) {
              ThemeMode.light => Icons.dark_mode_outlined,
              ThemeMode.dark => Icons.light_mode_outlined,
              ThemeMode.system => Icons.brightness_auto_outlined,
            };

            final tooltip = switch (tp.themeMode) {
              ThemeMode.light => 'تفعيل الوضع الداكن',
              ThemeMode.dark => 'تفعيل الوضع الفاتح',
              ThemeMode.system => 'الوضع التلقائي',
            };

            return IconButton(
              tooltip: tooltip,
              onPressed: () {
                final nextMode = switch (tp.themeMode) {
                  ThemeMode.light => ThemeMode.dark,
                  ThemeMode.dark => ThemeMode.system,
                  ThemeMode.system => ThemeMode.light,
                };
                tp.setThemeMode(nextMode);
              },
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: Tween(begin: 0.75, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  icon,
                  key: ValueKey(tp.themeMode),
                  color: isDark ? Colors.white : AppTheme.primaryColor,
                ),
              ),
            );
          },
        ),
      );
    }

    return result.isEmpty ? null : result;
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

