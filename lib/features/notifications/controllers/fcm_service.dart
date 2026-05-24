import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../firebase_options.dart';

// ── Background handler (must be top-level function) ──────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Message received while app is in background/terminated
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // Android notification channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for Splitly expense and payment notifications',
    importance: Importance.high,
  );

  // ── Initialize everything ─────────────────────────────────────────────────
  Future<void> initialize() async {
    // 1. Request permission from user (important for iOS)
    await _requestPermission();

    // 2. Setup local notifications (for foreground messages)
    await _setupLocalNotifications();

    // 3. Listen for messages
    _listenForMessages();

    // 4. Get and print FCM token (you'll save this to Supabase later)
    await _getToken();
  }

  // ── Request notification permission ───────────────────────────────────────
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('FCM Permission: ${settings.authorizationStatus}');
  }

  // ── Setup local notifications (shows alerts in foreground) ────────────────
  Future<void> _setupLocalNotifications() async {
    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Create high importance Android channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  // ── Listen for incoming messages ──────────────────────────────────────────
  void _listenForMessages() {
    // App is OPEN — show local notification manually
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
              color: const Color(0xFF0F766E), // Splitly teal
            ),
          ),
        );
      }
    });

    // App opened FROM a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification opened: ${message.data}');
      // Later: navigate to the relevant group/expense screen
    });
  }

  // ── Get FCM token for this device ─────────────────────────────────────────
  Future<String?> _getToken() async {
    final token = await _messaging.getToken();
    print('FCM Token: $token');
    // Later: save this token to Supabase profiles table
    // so Supabase Edge Functions can send targeted notifications
    return token;
  }

  // ── Public method to get token from anywhere ──────────────────────────────
  Future<String?> getToken() async => await _messaging.getToken();
}