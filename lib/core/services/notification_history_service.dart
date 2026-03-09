import '../db/database_helper.dart';
import '../models/notification_model.dart';

class NotificationHistoryService {
  NotificationHistoryService._();

  static final NotificationHistoryService instance = NotificationHistoryService._();

  Future<void> saveNotification(NotificationModel model) async {
    await DatabaseHelper.instance.insertNotification(model);
  }

  Future<List<NotificationModel>> getRecentNotifications({int limit = 100}) async {
    return DatabaseHelper.instance.getNotifications(limit: limit);
  }

  Future<int> getUnreadCount() async {
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
}

