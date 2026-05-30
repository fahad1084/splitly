import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../../firebase_options.dart';

// ── Background handler (must be top-level) ────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel =
  AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for Splitly expense and payment notifications',
    importance: Importance.high,
  );

  // ── Initialize ────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    await _requestPermission();
    await _setupLocalNotifications();
    _listenForMessages();
    await _saveTokenToSupabase();

    // Listen for token refresh and save again
    _messaging.onTokenRefresh.listen((newToken) {
      _saveToken(newToken);
    });
  }

  // ── Request permission ────────────────────────────────────────────────────
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('FCM Permission: ${settings.authorizationStatus}');
  }

  // ── Setup local notifications ─────────────────────────────────────────────
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
          android: androidSettings, iOS: iosSettings),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  // ── Listen for messages ───────────────────────────────────────────────────
  void _listenForMessages() {
    // App is OPEN — show local notification
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
              color: const Color(0xFF0F766E),
            ),
          ),
        );
      }
    });

    // App opened FROM notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification opened app: ${message.data}');
      // TODO: navigate to relevant screen based on message.data
    });
  }

  // ── Save FCM token to Supabase ────────────────────────────────────────────
  // Called on init and on token refresh
  // Token is stored in profiles.fcm_token column
  Future<void> _saveTokenToSupabase() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(token);
        print('FCM Token saved to Supabase: $token');
      }
    } catch (e) {
      print('FCM token save error: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await SupabaseConfig.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
    } catch (e) {
      print('Save token error: $e');
    }
  }

  // ── Public method to get token ────────────────────────────────────────────
  Future<String?> getToken() async => await _messaging.getToken();
}