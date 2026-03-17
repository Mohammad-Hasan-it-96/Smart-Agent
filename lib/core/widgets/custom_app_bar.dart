import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/push_notification_service.dart';

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
    // For root screens (no back button): place notifications bell in leading
    // so it appears on the RIGHT in RTL.
    final Widget? leadingWidget =
        (showNotifications && !automaticallyImplyLeading)
            ? _buildNotificationsBell(context)
            : null;

    return AppBar(
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
      centerTitle: true,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leadingWidget,
      actions: _buildActions(context),
      elevation: 0,
    );
  }

  // ── Notifications bell widget ──────────────────────────────────────
  Widget _buildNotificationsBell(BuildContext context) {
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
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            if (count > 0)
              Positioned(
                top: 6,
                left: 6,   // left in widget coords = RIGHT in RTL screen
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                        minWidth: 16, minHeight: 16),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
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
  List<Widget>? _buildActions(BuildContext context) {
    final List<Widget> result = [];

    // 1. Notifications bell for screens that HAVE a back button
    if (showNotifications && automaticallyImplyLeading) {
      result.add(_buildNotificationsBell(context));
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
          icon: const Icon(Icons.settings_outlined),
        ),
      );
    }

    // 4. Theme toggle (always last)
    if (showThemeToggle) {
      result.add(
        Consumer<ThemeProvider>(
          builder: (context, tp, _) {
            final icon = switch (tp.themeMode) {
              ThemeMode.light => Icons.light_mode_rounded,
              ThemeMode.dark => Icons.dark_mode_rounded,
              ThemeMode.system => Icons.brightness_auto_rounded,
            };

            final tooltip = switch (tp.themeMode) {
              ThemeMode.light => 'الوضع الحالي: فاتح',
              ThemeMode.dark => 'الوضع الحالي: داكن',
              ThemeMode.system => 'الوضع الحالي: تلقائي',
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
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => RotationTransition(
                    turns:
                        Tween(begin: 0.85, end: 1.0).animate(anim),
                    child: child),
                child: Icon(icon, key: ValueKey(tp.themeMode)),
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

