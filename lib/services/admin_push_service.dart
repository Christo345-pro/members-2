import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../platform/platform_features.dart';

class AdminPushService {
  AdminPushService._();

  static final AdminPushService instance = AdminPushService._();

  // Lazily access FirebaseMessaging so importing/instantiating this service
  // doesn't require Firebase to be initialised (e.g. Windows desktop builds).
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String _topic = 'wh_general';
  String _adminTopic = 'wh_admin_members';

  Future<void> init({
    String topic = 'wh_general',
    String adminTopic = 'wh_admin_members',
    void Function(RemoteMessage message)? onNewMember,
  }) async {
    if (_initialized) return;
    if (!supportsAdminPush) return;

    _topic = topic;
    _adminTopic = adminTopic;

    await Firebase.initializeApp();

    await _requestPermission();
    await _initLocalNotifications();

    await _messaging.subscribeToTopic(_topic);
    await _messaging.subscribeToTopic(_adminTopic);

    FirebaseMessaging.onMessage.listen((msg) async {
      await _showLocalNotification(msg);
      if ((msg.data['type'] ?? '').toString() == 'new_member') {
        onNewMember?.call(msg);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      if ((msg.data['type'] ?? '').toString() == 'new_member') {
        onNewMember?.call(msg);
      }
    });

    _initialized = true;
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    await _local.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );

    const channel = AndroidNotificationChannel(
      'wh_admin_members',
      'Admin Member Alerts',
      description: 'Notifications when new members join.',
      importance: Importance.high,
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showLocalNotification(RemoteMessage msg) async {
    final notif = msg.notification;
    final title = notif?.title ?? msg.data['title']?.toString() ?? 'New Alert';
    final body = notif?.body ?? msg.data['body']?.toString() ?? '';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'wh_admin_members',
        'Admin Member Alerts',
        channelDescription: 'Notifications when new members join.',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _local.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
