import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

typedef NotificationTapCallback = void Function(String? payload);

abstract class NotificationService {
  Future<void> initialize({NotificationTapCallback? onSelectNotification});
  Future<void> showProgressNotification({
    required int id,
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
    String? payload,
  });
  Future<void> showCompletionNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  });
  Future<void> showErrorNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  });
  Future<void> cancel(int id);
}

class NotificationServiceImpl implements NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final Map<int, DateTime> _lastUpdateTime = {};

  NotificationServiceImpl({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _notificationsPlugin = notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  static const String channelId = 'pos_file_transfers';
  static const String channelName = 'POS File Transfers';
  static const String channelDescription = 'Notifications for active and completed POS file transfers';

  @override
  Future<void> initialize({NotificationTapCallback? onSelectNotification}) async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (onSelectNotification != null) {
          onSelectNotification(response.payload);
        }
      },
    );

    // Request permissions for Android 13+
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }
  }

  @override
  Future<void> showProgressNotification({
    required int id,
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
    String? payload,
  }) async {
    // Throttle progress updates to at most once every 600ms per notification ID
    final now = DateTime.now();
    final last = _lastUpdateTime[id];
    if (last != null && now.difference(last).inMilliseconds < 600 && progress < maxProgress) {
      return;
    }
    _lastUpdateTime[id] = now;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.low, // Low prevents sound/vibration spam on progress updates
      priority: Priority.low,
      showProgress: true,
      maxProgress: maxProgress,
      progress: progress,
      ongoing: true,
      onlyAlertOnce: true,
      autoCancel: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentSound: false,
      presentBadge: false,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  @override
  Future<void> showCompletionNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    _lastUpdateTime.remove(id);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
      showProgress: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  @override
  Future<void> showErrorNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    _lastUpdateTime.remove(id);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) async {
    _lastUpdateTime.remove(id);
    await _notificationsPlugin.cancel(id);
  }
}
