import '../db/database_helper.dart';
import '../models/notification_model.dart';

class NotificationHistoryService {
  NotificationHistoryService._();

  static final NotificationHistoryService instance = NotificationHistoryService._();

  Future<void> saveNotification(NotificationModel model) async {
    if (!_isValidNotification(model.title, model.body)) return;
    await DatabaseHelper.instance.insertNotification(model);
  }

  Future<List<NotificationModel>> getRecentNotifications({int limit = 100}) async {
    await purgeInvalidNotifications();
    return DatabaseHelper.instance.getNotifications(limit: limit);
  }

  Future<int> getUnreadCount() async {
    await purgeInvalidNotifications();
    return DatabaseHelper.instance.getUnreadNotificationsCount();
  }

  Future<void> markAsRead(int id) async {
    await DatabaseHelper.instance.markNotificationAsRead(id);
  }

  Future<void> markAllAsRead() async {
    await DatabaseHelper.instance.markAllNotificationsAsRead();
  }

  Future<void> clearAll() async {
    await DatabaseHelper.instance.clearNotifications();
  }

  Future<void> purgeInvalidNotifications() async {
    await DatabaseHelper.instance.deleteInvalidNotifications();
  }

  bool _isValidNotification(String? title, String? body) {
    final safeTitle = (title ?? '').trim();
    final safeBody = (body ?? '').trim();
    return safeTitle.isNotEmpty && safeBody.isNotEmpty;
  }
}

