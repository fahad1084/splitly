import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../../../config/supabase/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../firebase_options.dart';
import '../../../l10n/app_localizations.dart';
import '../../security/controllers/app_lock_controller.dart';
import '../../settings/controllers/locale_controller.dart';
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

  /// Set by the app (AuthGate) to reload what a push says has changed,
  /// while the app is open.
  static void Function(Map<String, dynamic> data)? onForegroundData;

  // ── Tapped notifications ──────────────────────────────────────────────────
  // The app sets the handler once Home is showing (and clears it on sign
  // out). A tap that comes earlier — the app was closed, or still starting —
  // waits in _pendingOpen until then.
  static void Function(Map<String, dynamic> data)? _onOpen;
  static Map<String, dynamic>? _pendingOpen;

  static void setOpenHandler(void Function(Map<String, dynamic> data)? handler) {
    _onOpen = handler;
    final pending = _pendingOpen;
    if (handler != null && pending != null) {
      _pendingOpen = null;
      handler(pending);
    }
  }

  static void _open(Map<String, dynamic> data) {
    final handler = _onOpen;
    if (handler != null) {
      handler(data);
    } else {
      _pendingOpen = data;
    }
  }

  // Our notifications carry {type, group_id, entity_id} as JSON
  static void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      _open(Map<String, dynamic>.from(jsonDecode(payload) as Map));
    } catch (e) {
      logDebug('=== NOTIFICATION TAP: bad payload: $e ===');
    }
  }

  // ── Initialize ────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    await _requestPermission();
    await _setupLocalNotifications();
    _listenForMessages();

    // The app was started by tapping one of our notifications
    final launch = await _localNotifications.getNotificationAppLaunchDetails();
    final launchResponse = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) && launchResponse != null) {
      _onTap(launchResponse);
    }
    // ... or a system-shown FCM notification (not used today, kept safe)
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _open(initial.data);
    // Needs internet: runs in the background so the app also opens offline
    unawaited(saveTokenToSupabase());

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
      onDidReceiveNotificationResponse: _onTap,
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
      onForegroundData?.call(message.data);
    });

    // App opened FROM a system-shown FCM notification (ours are shown by
    // flutter_local_notifications, see _onTap)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _open(message.data);
    });
  }

  // ── Build + show the actual notification from a data-only FCM payload ────
  // Static + top-level-callable so the background isolate (which has no
  // access to the running app's instance) can use it too.
  static Future<void> _showFromData(Map<String, dynamic> data) async {
    var title = data['title'] as String? ?? 'Splitly';
    var body = data['body'] as String? ?? '';
    var avatarUrl = data['avatar_url'] as String?;

    // App lock on → no message text, amounts or sender photo on this phone.
    // The title is always the group name (see send-push-notification).
    if (await _isAppLockOn()) {
      final l10n = await _savedLocalizations();
      final group = title;
      title = l10n.appName;
      body = data['type'] == 'message'
          ? l10n.lockedNotificationMessage(group)
          : l10n.lockedNotificationActivity(group);
      avatarUrl = null;
    }

    final localNotifications = FlutterLocalNotificationsPlugin();
    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    await localNotifications.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onTap,
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
      // What to open when tapped (no text or amounts in here)
      payload: jsonEncode({
        'type': data['type'] ?? '',
        'group_id': data['group_id'] ?? '',
        'entity_id': data['entity_id'] ?? '',
      }),
    );
  }

  // Read fresh from disk: this may run in the background isolate, whose
  // cached prefs don't see the user turning the lock on or off.
  static Future<bool> _isAppLockOn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getBool(kLockEnabledKey) ?? false;
    } catch (e) {
      logDebug('App lock check for notification failed: $e');
      return true; // can't tell → keep the content private
    }
  }

  // No BuildContext here (maybe no UI at all) → use the saved app language
  static Future<AppLocalizations> _savedLocalizations() async {
    var code = 'en';
    try {
      final prefs = await SharedPreferences.getInstance();
      code = prefs.getString(kLocaleKey) ?? 'en';
    } catch (_) {}
    return lookupAppLocalizations(Locale(code == 'ur' ? 'ur' : 'en'));
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