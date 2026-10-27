import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/supabase/supabase_config.dart';
import 'package:splitly/core/utils/app_logger.dart';
import 'package:splitly/core/utils/app_errors.dart';

// ── Notification model ──────────────────────────────────────────────────────
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? groupId;
  final String? entityId;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.groupId,
    this.entityId,
    this.readAt,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      type: map['type'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      groupId: map['group_id'] as String?,
      entityId: map['entity_id'] as String?,
      readAt: map['read_at'] == null
          ? null
          : DateTime.parse(map['read_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

// ── Notification history list ───────────────────────────────────────────────
final notificationsProvider =
FutureProvider<List<AppNotification>>((ref) async {
  final userId = SupabaseConfig.client.auth.currentUser?.id;
  if (userId == null) return [];
  try {
    final List<dynamic> rows = await SupabaseConfig.client
        .from('notifications')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100);
    return rows
        .map((r) => AppNotification.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  } catch (e, st) {
    // Shown as an error with "Try again", not as "no notifications"
    errorCode(e, st, where: 'notifications');
    rethrow;
  }
});

// ── Unread notification count (for a bell badge) ────────────────────────────
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final notifications = await ref.watch(notificationsProvider.future);
  return notifications.where((n) => n.isUnread).length;
});

// ── Notification preferences ────────────────────────────────────────────────
final notificationPrefsProvider =
FutureProvider<Map<String, bool>>((ref) async {
  final userId = SupabaseConfig.client.auth.currentUser?.id;
  if (userId == null) return {};
  try {
    final data = await SupabaseConfig.client
        .from('profiles')
        .select(
        'notify_messages, notify_expenses, notify_settlements, notify_members, notify_debt_reminders')
        .eq('id', userId)
        .maybeSingle();
    return {
      'notify_messages': data?['notify_messages'] as bool? ?? true,
      'notify_expenses': data?['notify_expenses'] as bool? ?? true,
      'notify_settlements': data?['notify_settlements'] as bool? ?? true,
      'notify_members': data?['notify_members'] as bool? ?? true,
      'notify_debt_reminders': data?['notify_debt_reminders'] as bool? ?? true,
    };
  } catch (e) {
    logDebug('=== FETCH NOTIFICATION PREFS ERROR: $e ===');
    return {};
  }
});

class NotificationsController {
  static Future<void> markAsRead(String notificationId) async {
    try {
      await SupabaseConfig.client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', notificationId);
    } catch (e) {
      logDebug('=== MARK NOTIFICATION READ ERROR: $e ===');
    }
  }

  static Future<void> markAllAsRead(String userId) async {
    try {
      await SupabaseConfig.client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', userId)
          .isFilter('read_at', null);
    } catch (e) {
      logDebug('=== MARK ALL NOTIFICATIONS READ ERROR: $e ===');
    }
  }

  static Future<void> updatePreference(String column, bool value) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseConfig.client
          .from('profiles')
          .update({column: value}).eq('id', userId);
    } catch (e) {
      logDebug('=== UPDATE NOTIFICATION PREF ERROR: $e ===');
    }
  }
}