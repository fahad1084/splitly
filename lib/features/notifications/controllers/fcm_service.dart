import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../../firebase_options.dart';
import 'package:splitly/core/utils/app_logger.dart';

// ── Background handler (must be top-level) ────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FCMService._showFromData(message.data);
}

// ── Download raw image bytes for a notification's large icon ───────────────
// Returns null on any failure — caller falls back to no large icon (just
// the app's small icon), never crashes the notification pipeline.
Future<Uint8List?> _downloadAvatarBytes(String? url) async {
  if (url == null || url.isEmpty) return null;
  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) return null;
    final bytes = await response.fold<List<int>>(
      <int>[],
          (previous, element) => previous..addAll(element),
    );
    client.close();
    return Uint8List.fromList(bytes);
  } catch (e) {
    logDebug('=== AVATAR DOWNLOAD ERROR: $e ===');
    return null;
  }
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
    await saveTokenToSupabase();

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
    logDebug('FCM Permission: ${settings.authorizationStatus}');
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
    // App is OPEN — build and show local notification from data payload
    // (messages are now data-only, so message.notification is always null —
    // we build the visible notification ourselves, WhatsApp-style, with the
    // sender's avatar as the large icon).
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      FCMService._showFromData(message.data);
    });

    // App opened FROM notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // TODO: navigate to relevant screen based on message.data
    });
  }

  // ── Build + show the actual notification from a data-only FCM payload ────
  // Static + top-level-callable so the background isolate (which has no
  // access to the running app's instance) can use it too.
  static Future<void> _showFromData(Map<String, dynamic> data) async {
    final title = data['title'] as String? ?? 'Splitly';
    final body = data['body'] as String? ?? '';
    final avatarUrl = data['avatar_url'] as String?;

    final localNotifications = FlutterLocalNotificationsPlugin();
    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    await localNotifications.initialize(
      const InitializationSettings(android: androidSettings),
    );
    await localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    final avatarBytes = await _downloadAvatarBytes(avatarUrl);

    await localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF0F766E),
          largeIcon: avatarBytes != null
              ? ByteArrayAndroidBitmap(avatarBytes)
              : null,
        ),
      ),
    );
  }

  // ── Save FCM token to Supabase ────────────────────────────────────────────
  // Called on init, on every sign-in, and on token refresh
  // Token is stored in profiles.fcm_token column
  Future<void> saveTokenToSupabase() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(token);
        logDebug('FCM Token saved to Supabase');
      }
    } catch (e) {
      logDebug('FCM token save error: $e');
    }
  }

  // ── Clear FCM token from Supabase ─────────────────────────────────────────
  // Must run BEFORE auth.signOut() — RLS needs the session to update the row.
  // Only clears the column if it still holds THIS device's token, so a newer
  // login on another device keeps its pushes.
  Future<void> clearTokenFromSupabase() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await SupabaseConfig.client
          .from('profiles')
          .update({'fcm_token': null})
          .eq('id', userId)
          .eq('fcm_token', token);
    } catch (e) {
      logDebug('Clear token error: $e');
    }
  }

  // ── Delete this device's FCM token at Firebase ────────────────────────────
  // Called after sign-out. Even if clearing the DB column failed (offline,
  // expired session), the old token stops working, so the logged-out user's
  // pushes can no longer reach this device. A fresh token is created by
  // getToken() on the next sign-in.
  Future<void> deleteDeviceToken() async {
    try {
      await _messaging.deleteToken();
    } catch (e) {
      logDebug('Delete device token error: $e');
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
      logDebug('Save token error: $e');
    }
  }

  // ── Public method to get token ────────────────────────────────────────────
  Future<String?> getToken() async => await _messaging.getToken();
}