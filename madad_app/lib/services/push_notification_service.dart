import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';

class PushNotificationService {
  static final _messaging  = FirebaseMessaging.instance;
  static final _localNotif = FlutterLocalNotificationsPlugin();
  static bool  _initialized = false;

  static Future<void> init() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[Push] Permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    if (!kIsWeb) {
      await _setupLocalNotifications();
    }

    final token = await _messaging.getToken();
    debugPrint('[Push] FCM token: $token');
    if (token != null) await _sendToken(token);

    if (!_initialized) {
      _messaging.onTokenRefresh.listen(_sendToken);
      _initialized = true;
    }
  }

  static Future<void> _setupLocalNotifications() async {
    const channelId   = 'gasp_zero_channel';
    const channelName = "Gasp'Zero Notifications";
    const channelDesc = 'Donation and reservation alerts';

    final androidPlugin = _localNotif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDesc,
        importance: Importance.high,
      ),
    );

    await _localNotif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('[Push] Foreground: ${msg.notification?.title}');
      _showLocal(msg);
    });
  }

  static Future<void> dispose() async {
    await _messaging.deleteToken();
    _initialized = false;
    debugPrint('[Push] FCM token deleted');
  }

  static Future<void> _sendToken(String token) async {
    try {
      await NotificationService().updateFcmToken(token);
      debugPrint('[Push] Token sent to backend ✅');
    } catch (e) {
      debugPrint('[Push] Failed to send token: $e');
    }
  }

  static void _showLocal(RemoteMessage message) {
    if (kIsWeb) return;
    final notif = message.notification;
    if (notif == null) return;

    _localNotif.show(
      notif.hashCode,
      notif.title,
      notif.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'gasp_zero_channel',
          "Gasp'Zero Notifications",
          channelDescription: 'Donation and reservation alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}