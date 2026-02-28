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
            final isDark = tp.themeMode == ThemeMode.dark ||
                (tp.themeMode == ThemeMode.system &&
                    MediaQuery.platformBrightnessOf(context) == Brightness.dark);
            return IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) =>
                    RotationTransition(turns: Tween(begin: 0.75, end: 1.0).animate(anim), child: child),
                child: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  key: ValueKey(isDark),
                ),
              ),
              tooltip: isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
              onPressed: () {
                tp.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
              },
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

