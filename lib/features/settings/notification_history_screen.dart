import 'package:flutter/material.dart';

import '../../core/models/notification_model.dart';
import '../../core/services/notification_history_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/widgets/custom_app_bar.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  bool _loading = true;
  List<NotificationModel> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await NotificationHistoryService.instance.getRecentNotifications(limit: 200);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _markRead(NotificationModel item) async {
    if (item.id == null || item.isRead) return;
    await NotificationHistoryService.instance.markAsRead(item.id!);
    await PushNotificationService.instance.refreshUnreadCount();
    await _load();
  }

  Future<void> _markAllRead() async {
    await PushNotificationService.instance.markAllNotificationsAsRead();
    await _load();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مسح جميع الإشعارات'),
        content: const Text('هل أنت متأكد من حذف جميع الإشعارات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('مسح'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await PushNotificationService.instance.clearAllNotifications();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'الإشعارات',
        actions: [
          IconButton(
            tooltip: 'تعليم الكل كمقروء',
            icon: const Icon(Icons.done_all_rounded),
            onPressed: _items.isEmpty ? null : _markAllRead,
          ),
          IconButton(
            tooltip: 'مسح الكل',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _items.isEmpty ? null : _clearAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _items.length,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _buildItem(_items[i]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade500),
            const SizedBox(height: 10),
            const Text('لا توجد إشعارات بعد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('عند وصول أي إشعار سيظهر هنا.', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(NotificationModel item) {
    final theme = Theme.of(context);
    final isRead = item.isRead;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _markRead(item),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? theme.dividerColor.withValues(alpha: 0.25)
                : theme.colorScheme.primary.withValues(alpha: 0.35),
          ),
          color: isRead
              ? theme.colorScheme.surface
              : theme.colorScheme.primary.withValues(alpha: 0.08),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isRead ? Icons.notifications_none : Icons.notifications_active,
              color: isRead ? Colors.grey : theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(item.body, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(item.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d  $h:$min';
  }
}

