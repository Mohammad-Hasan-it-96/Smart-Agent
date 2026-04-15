import 'package:flutter/material.dart';

import '../empty_state.dart';

class IndexUiTokens {
  static const EdgeInsets headerPadding = EdgeInsets.fromLTRB(16, 10, 16, 10);
  static const EdgeInsets cardMargin = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
  static const EdgeInsets cardPadding = EdgeInsets.all(12);
  static const EdgeInsets listBottomPadding = EdgeInsets.only(bottom: 92);
  static const double cardRadius = 16;
}

class IndexHeaderSection extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final String hintText;
  final Widget? controls;
  final List<Widget> filterChips;

  const IndexHeaderSection({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.hintText,
    this.controls,
    this.filterChips = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: IndexUiTokens.headerPadding,
      child: Column(
        children: [
          TextField(
            controller: searchController,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: searchController.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          if (controls != null) ...[
            const SizedBox(height: 9),
            controls!,
          ],
          if (filterChips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filterChips,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class IndexFilterChip extends StatelessWidget {
  final String text;

  const IndexFilterChip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall,
        textDirection: TextDirection.rtl,
      ),
    );
  }
}

class IndexInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const IndexInfoChip({
    super.key,
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: effectiveColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: effectiveColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class IndexEmptySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onAdd;
  final String? addLabel;

  const IndexEmptySection({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onAdd,
    this.addLabel,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: icon,
      title: title,
      message: message,
      action: onAdd != null && addLabel != null
          ? FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(addLabel!),
            )
          : null,
    );
  }
}

class IndexSkeletonCard extends StatelessWidget {
  const IndexSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Card(
      margin: IndexUiTokens.cardMargin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IndexUiTokens.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 18,
              width: 180,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

