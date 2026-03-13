import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final bool showThemeToggle;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.showThemeToggle = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
      centerTitle: true,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: _buildActions(context),
      elevation: 0,
    );
  }

  List<Widget>? _buildActions(BuildContext context) {
    final List<Widget> result = [];

    // Custom actions first (e.g. trial badge)
    if (actions != null) {
      result.addAll(actions!);
    }

    // Theme toggle
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
                transitionBuilder: (child, anim) =>
                    RotationTransition(turns: Tween(begin: 0.85, end: 1.0).animate(anim), child: child),
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

