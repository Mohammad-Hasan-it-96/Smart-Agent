import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_model.dart';
import 'activation_service.dart';
import 'notification_action_handler.dart';
import 'notification_api_service.dart';
import 'notification_history_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  await PushNotificationService.instance.storeMessageToHistory(message);
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const String _channelId = 'subscription_channel';
  static const String _channelName = 'Subscription';
  static const String _fcmTokenKey = 'fcm_token';
  static const String _fcmRegisteredOnceKey = 'fcm_registered_once';

  late final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ActivationService _activationService = ActivationService();
  final NotificationApiService _apiService = NotificationApiService();

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  final ValueNotifier<int> activationRefreshEvents = ValueNotifier<int>(0);

  bool _initialized = false;
  bool _isShowingActivationDialog = false;
  RemoteMessage? _pendingOpenedMessage;
  Map<String, dynamic>? _pendingLocalPayload;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Firebase config can be unavailable in some local environments.
      return;
    }

    _messaging = FirebaseMessaging.instance;

    await _initLocalNotifications();
    await NotificationHistoryService.instance.purgeInvalidNotifications();
    await _refreshUnreadCount();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();

    await _syncTokenOnLaunch();

    _messaging.onTokenRefresh.listen((token) async {
      await _updateToken(token);
    });

    FirebaseMessaging.onMessage.listen((message) async {
      await storeMessageToHistory(message);
      await _handleForegroundActivationMessage(message);
      await _showForegroundNotification(message);
      await _refreshUnreadCount();
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await storeMessageToHistory(message, markRead: true);
      await _refreshUnreadCount();
      await _handleMessageAction(message);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _pendingOpenedMessage = initialMessage;
      await storeMessageToHistory(initialMessage, markRead: true);
      await _refreshUnreadCount();
    }

    _initialized = true;
  }

  Future<void> flushPendingNavigation(BuildContext context) async {
    if (_pendingOpenedMessage != null) {
      final message = _pendingOpenedMessage!;
      _pendingOpenedMessage = null;
      await _handleMessageAction(message, contextOverride: context);
      return;
    }

    if (_pendingLocalPayload != null) {
      final payload = _pendingLocalPayload!;
      _pendingLocalPayload = null;
      await NotificationActionHandler.handle(
        context,
        type: (payload['type'] ?? '') as String,
        action: payload['action'] as String?,
        title: payload['title'] as String?,
        body: payload['body'] as String?,
      );
    }
  }

  Future<void> retryTokenSync() async {
    await _syncTokenOnLaunch(forceRegisterAttempt: true);
  }

  Future<void> storeMessageToHistory(
    RemoteMessage message, {
    bool markRead = false,
  }) async {
    final data = message.data;
    final title = (message.notification?.title ?? data['title']?.toString() ?? '').trim();
    final body = (message.notification?.body ?? data['body']?.toString() ?? '').trim();
    if (!_isValidNotification(title, body)) return;
    final type = (data['type'] ?? 'general').toString();
    final action = (data['action'] ?? '').toString();

    final model = NotificationModel(
      title: title,
      body: body,
      type: type,
      action: action,
      createdAt: DateTime.now(),
      isRead: markRead,
    );

    await NotificationHistoryService.instance.saveNotification(model);
  }

  Future<void> markAllNotificationsAsRead() async {
    await NotificationHistoryService.instance.markAllAsRead();
    await refreshUnreadCount();
  }

  Future<void> clearAllNotifications() async {
    await NotificationHistoryService.instance.clearAll();
    await refreshUnreadCount();
  }

  Future<void> refreshUnreadCount() async {
    unreadCount.value = await NotificationHistoryService.instance.getUnreadCount();
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) async {
        if (response.payload == null || response.payload!.isEmpty) return;
        final payload = jsonDecode(response.payload!) as Map<String, dynamic>;

        final context = _currentContext;
        if (context == null) {
          _pendingLocalPayload = payload;
          return;
        }

        await NotificationActionHandler.handle(
          context,
          type: (payload['type'] ?? '') as String,
          action: payload['action'] as String?,
          title: payload['title'] as String?,
          body: payload['body'] as String?,
        );
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.high,
            playSound: true,
          ),
        );
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> _syncTokenOnLaunch({bool forceRegisterAttempt = false}) async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fcmTokenKey, token);

    final registered = prefs.getBool(_fcmRegisteredOnceKey) ?? false;
    if (!registered || forceRegisterAttempt) {
      final ok = await _registerTokenOnce(token);
      if (ok) {
        await prefs.setBool(_fcmRegisteredOnceKey, true);
      }
    }
  }

  Future<bool> _registerTokenOnce(String token) async {
    final fullName = await _activationService.getAgentName();
    final phone = await _activationService.getAgentPhone();
    if (fullName.isEmpty || phone.isEmpty) {
      return false;
    }

    final deviceId = await _activationService.getDeviceId();

    try {
      return await _apiService.sendCreateDeviceWithToken(
        appName: 'SmartAgent',
        deviceId: deviceId,
        fullName: fullName,
        phone: phone,
        fcmToken: token,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _updateToken(String token) async {
    if (token.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fcmTokenKey, token);

    final deviceId = await _activationService.getDeviceId();

    try {
      await _apiService.updateFcmToken(deviceId: deviceId, fcmToken: token);
    } catch (_) {
      // Keep local token and retry next app launch.
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final data = message.data;
    final title = (message.notification?.title ?? data['title']?.toString() ?? '').trim();
    final body = (message.notification?.body ?? data['body']?.toString() ?? '').trim();
    if (!_isValidNotification(title, body)) return;
    final type = (data['type'] ?? 'general').toString();
    final action = (data['action'] ?? '').toString();

    final payload = jsonEncode({
      'type': type,
      'action': action,
      'title': title,
      'body': body,
    });

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
      payload: payload,
    );
  }

  Future<void> _handleMessageAction(
    RemoteMessage message, {
    BuildContext? contextOverride,
  }) async {
    final data = message.data;
    final context = contextOverride ?? _currentContext;
    if (context == null) {
      _pendingOpenedMessage = message;
      return;
    }

    await NotificationActionHandler.handle(
      context,
      type: (data['type'] ?? 'general').toString(),
      action: data['action']?.toString(),
      title: message.notification?.title ?? data['title']?.toString(),
      body: message.notification?.body ?? data['body']?.toString(),
    );
  }

  Future<void> _refreshUnreadCount() async {
    await refreshUnreadCount();
  }

  BuildContext? get _currentContext => AppNavigatorKey.key.currentContext;

  bool _isValidNotification(String? title, String? body) {
    final safeTitle = (title ?? '').trim();
    final safeBody = (body ?? '').trim();
    return safeTitle.isNotEmpty && safeBody.isNotEmpty;
  }

  Future<void> _handleForegroundActivationMessage(RemoteMessage message) async {
    final type = (message.data['type'] ?? '').toString().trim();
    if (type != 'new_plan_activated') return;

    bool verified = false;
    try {
      verified = await _activationService.recheckActivationStatus();
    } catch (_) {
      return;
    }
    if (!verified) return;

    activationRefreshEvents.value++;
    await _showActivationSuccessDialog();
  }

  Future<void> _showActivationSuccessDialog() async {
    final context = _currentContext;
    if (context == null || _isShowingActivationDialog) return;
    _isShowingActivationDialog = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 32),
          title: const Text(
            'تم تفعيل اشتراكك بنجاح',
            textDirection: TextDirection.rtl,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Ignore UI errors if context changes while dialog is open.
    } finally {
      _isShowingActivationDialog = false;
    }
  }
}

class AppNavigatorKey {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
}

