import 'package:flutter/material.dart';

/// Lightweight in-screen undo bar that auto-hides after [duration].
///
/// Usage inside a StatefulWidget:
/// 1. Add `UndoBarState? _undoState;` and `Timer? _undoTimer;`
/// 2. After delete, call `_showUndoBar(label, onUndo)`
/// 3. In build, wrap body with `Stack` and add `UndoBar` at bottom
/// 4. Dispose timer in `dispose()`
class UndoBar extends StatelessWidget {
  final String message;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;

  const UndoBar({
    super.key,
    required this.message,
    required this.onUndo,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Positioned(
      left: 24,
      right: 24,
      bottom: 90,
      child: Material(
        elevation: 2,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onUndo,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      'تراجع',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

