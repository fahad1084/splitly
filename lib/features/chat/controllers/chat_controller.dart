import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../../core/utils/string_utils.dart';
import '../models/message_model.dart';
import 'package:splitly/core/utils/app_logger.dart';
import 'package:splitly/core/utils/app_errors.dart';

// ── Messages provider per group ───────────────────────────────────────────────
// autoDispose: leaving the chat frees the messages and closes the realtime
// channel (ref.onDispose below).
final messagesProvider = AsyncNotifierProvider.autoDispose
    .family<ChatController, List<MessageModel>, String>(
  ChatController.new,
);

/// Messages per page — the newest page first, older ones on scroll up.
const kChatPageSize = 50;

class ChatController
    extends AutoDisposeFamilyAsyncNotifier<List<MessageModel>, String> {
  String get _groupId => arg;
  RealtimeChannel? _channel;

  // Sender profiles already loaded (id → full_name, avatar_url,
  // avatar_color), so a realtime message needs no extra request.
  final _profiles = <String, Map<String, dynamic>>{};

  bool _hasMore = true;
  bool _loadingOlder = false;

  /// False once the very first message of the group is loaded.
  bool get hasMore => _hasMore;

  @override
  Future<List<MessageModel>> build(String arg) async {
    // Newest page first
    final messages = await _fetchPage();

    // Subscribe to realtime new messages
    _subscribeToRealtime();

    // Clean up channel (and the typing timer) when the chat is left
    ref.onDispose(() {
      _typingIdle?.cancel();
      _channel?.unsubscribe();
    });

    return messages;
  }

  // ── Mark this group's chat as read (for unread badges) ────────────────────
  Future<void> markAsRead() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseConfig.client.from('chat_read_status').upsert({
        'group_id': _groupId,
        'user_id': userId,
        'last_read_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      logDebug('=== MARK AS READ ERROR: $e ===');
    }
  }

  // ── Load the page before the oldest message shown ─────────────────────────
  Future<void> loadOlder() async {
    final current = state.value;
    if (!_hasMore || _loadingOlder || current == null || current.isEmpty) {
      return;
    }
    _loadingOlder = true;
    try {
      final older = await _fetchPage(
          before: current.first.createdAt, alreadyLoaded: current);
      final known = current.map((m) => m.id).toSet();
      state = AsyncValue.data([
        ...older.where((m) => !known.contains(m.id)),
        ...state.value ?? current,
      ]);
    } catch (e) {
      logDebug('=== LOAD OLDER MESSAGES ERROR: $e ===');
    } finally {
      _loadingOlder = false;
    }
  }

  // ── Load sender profiles we don't have yet (one request, or none) ─────────
  Future<void> _loadProfiles(Iterable<String> ids) async {
    final missing = ids.where((id) => !_profiles.containsKey(id)).toSet();
    if (missing.isEmpty) return;
    final List<dynamic> rows = await SupabaseConfig.client
        .from('profiles')
        .select('id, full_name, avatar_url, avatar_color')
        .inFilter('id', missing.toList());
    for (final p in rows) {
      _profiles[p['id'] as String] = Map<String, dynamic>.from(p);
    }
  }

  MessageModel _toModel(
      Map<String, dynamic> row, Map<String, Map<String, dynamic>> byId) {
    final sender = _profiles[row['sender_id']];
    final replyToId = row['reply_to_id'] as String?;
    final reply = replyToId == null ? null : byId[replyToId];
    return MessageModel.fromMap({
      ...row,
      'sender_name': sender?['full_name'] as String? ?? 'Unknown',
      'sender_avatar_url': sender?['avatar_url'],
      'sender_avatar_color': sender?['avatar_color'],
      'reply_to_content': reply?['content'],
      'reply_to_sender': reply == null
          ? null
          : _profiles[reply['sender_id']]?['full_name'] as String? ??
              'Unknown',
    });
  }

  // ── Fetch one page (newest first from the DB, returned oldest → newest) ───
  // A reply can point to a message in this page or one already shown.
  Future<List<MessageModel>> _fetchPage({
    DateTime? before,
    List<MessageModel> alreadyLoaded = const [],
  }) async {
    var query = SupabaseConfig.client
        .from('messages')
        .select('*')
        .eq('group_id', _groupId);
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }
    final List<dynamic> desc =
        await query.order('created_at', ascending: false).limit(kChatPageSize);
    if (desc.length < kChatPageSize) _hasMore = false;
    if (desc.isEmpty) return [];

    final rows =
        desc.reversed.map((r) => Map<String, dynamic>.from(r)).toList();
    await _loadProfiles(rows.map((r) => r['sender_id'] as String));

    final byId = <String, Map<String, dynamic>>{
      for (final m in alreadyLoaded)
        m.id: {'content': m.content, 'sender_id': m.senderId},
      for (final r in rows) r['id'] as String: r,
    };
    return rows.map((r) => _toModel(r, byId)).toList();
  }

  // ── Realtime subscription ─────────────────────────────────────────────────
  void _subscribeToRealtime() {
    _channel = SupabaseConfig.client
        .channel('messages:$_groupId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'group_id',
        value: _groupId,
      ),
      callback: (payload) async {
        final newRow = payload.newRecord;
        if (newRow.isEmpty) return;

        try {
          // Only asks the database for someone we haven't seen yet
          await _loadProfiles([newRow['sender_id'] as String]);

          final current = state.value ?? [];
          final byId = <String, Map<String, dynamic>>{
            for (final m in current)
              m.id: {'content': m.content, 'sender_id': m.senderId},
          };
          final message = _toModel(Map<String, dynamic>.from(newRow), byId);

          // Avoid duplicates
          if (!current.any((m) => m.id == message.id)) {
            state = AsyncValue.data([...current, message]);
          }
        } catch (e) {
          logDebug('=== REALTIME MESSAGE ERROR: $e ===');
        }
      },
    )
        .subscribe();
  }

  // ── Send text message (with optional reply) ─────────────────────────────
  Future<String?> sendMessage(String content, {String? replyToId}) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return kErrNotSignedIn;
    if (content.trim().isEmpty) return null;

    try {
      await SupabaseConfig.client.from('messages').insert({
        'id': const Uuid().v4(),
        'group_id': _groupId,
        'sender_id': userId,
        'content': content.trim(),
        'reply_to_id': replyToId,
      });
      return null;
    } catch (e, st) {
      return errorCode(e, st, where: 'sendMessage');
    }
  }
  // ── Delete a message (sender only, enforced by RLS) ─────────────────────
  Future<String?> deleteMessage(String messageId) async {
    try {
      await SupabaseConfig.client.from('messages').delete().eq('id', messageId);
      final current = state.value ?? [];
      state = AsyncValue.data(current.where((m) => m.id != messageId).toList());
      return null;
    } catch (e, st) {
      return errorCode(e, st, where: 'deleteMessage');
    }
  }

  // ── Typing indicator ──────────────────────────────────────────────────────
  // Sent once when typing starts, refreshed at most every 3 s while the
  // user keeps typing (others hide entries older than 5 s), and removed
  // after 4 s without a key press, on send, or when the chat is left.
  static const _typingRefresh = Duration(seconds: 3);
  static const _typingIdleAfter = Duration(seconds: 4);
  DateTime? _typingSentAt;
  Timer? _typingIdle;

  /// Call on every text change while the field is not empty.
  void onUserTyping() {
    _typingIdle?.cancel();
    _typingIdle = Timer(_typingIdleAfter, stopTyping);
    final sent = _typingSentAt;
    if (sent != null && DateTime.now().difference(sent) < _typingRefresh) {
      return;
    }
    _typingSentAt = DateTime.now();
    _sendTyping();
  }

  Future<void> _sendTyping() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _loadProfiles([userId]); // my name, loaded once
      await SupabaseConfig.client.from('typing_status').upsert({
        'group_id': _groupId,
        'user_id': userId,
        'user_name': _profiles[userId]?['full_name'],
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Removes "typing…" — only if we actually sent it.
  Future<void> stopTyping() async {
    _typingIdle?.cancel();
    if (_typingSentAt == null) return;
    _typingSentAt = null;
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseConfig.client
          .from('typing_status')
          .delete()
          .eq('group_id', _groupId)
          .eq('user_id', userId);
    } catch (_) {}
  }

  // ── Send image attachment ─────────────────────────────────────────────────
  Future<String?> sendImage(File imageFile, {String caption = ''}) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return kErrNotSignedIn;

    try {
      final ext = imageFile.path.split('.').last;
      final fileName = '${const Uuid().v4()}.$ext';
      final path = '$_groupId/$fileName';

      await SupabaseConfig.client.storage
          .from('chat-attachments')
          .upload(path, imageFile);

      // The bucket is private: store the storage PATH, and show it later
      // through a signed URL (see attachmentSignedUrlProvider).
      try {
        await SupabaseConfig.client.from('messages').insert({
          'id': const Uuid().v4(),
          'group_id': _groupId,
          'sender_id': userId,
          'content': caption,          // the caption goes here
          'attachment_url': path,
          'attachment_type': 'image',
        });
      } catch (_) {
        await _removeUpload(path); // don't leave an orphan file behind
        rethrow;
      }
      return null;
    } catch (e, st) {
      return errorCode(e, st, where: 'sendImage');
    }
  }


  // ── Send voice message ────────────────────────────────────────────────────
  Future<String?> sendAudio(File audioFile, int durationSeconds) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return kErrNotSignedIn;

    try {
      final fileName = '${const Uuid().v4()}.m4a';
      final path = '$_groupId/$fileName';

      await SupabaseConfig.client.storage
          .from('chat-attachments')
          .upload(path, audioFile);

      try {
        await SupabaseConfig.client.from('messages').insert({
          'id': const Uuid().v4(),
          'group_id': _groupId,
          'sender_id': userId,
          'content': '',
          'attachment_url': path, // private bucket — see sendImage
          'attachment_type': 'audio',
          'audio_duration': durationSeconds,
        });
      } catch (_) {
        await _removeUpload(path); // don't leave an orphan file behind
        rethrow;
      }
      return null;
    } catch (e, st) {
      return errorCode(e, st, where: 'sendAudio');
    }
  }

  // ── Delete a file we just uploaded (best effort) ──────────────────────────
  Future<void> _removeUpload(String path) async {
    try {
      await SupabaseConfig.client.storage
          .from(_chatAttachmentsBucket)
          .remove([path]);
    } catch (_) {}
  }
}

// ── Typing status stream — who is currently typing in this group ─────────────
// autoDispose: the stream (a realtime channel) closes when the chat is left.
final typingUsersProvider =
StreamProvider.autoDispose.family<List<String>, String>((ref, groupId) {
  final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
  return SupabaseConfig.client
      .from('typing_status')
      .stream(primaryKey: ['group_id', 'user_id'])
      .eq('group_id', groupId)
      .map((rows) {
    final now = DateTime.now();
    return rows
        .where((r) {
      // Ignore self and stale entries older than 5 seconds
      final updatedAt = DateTime.parse(r['updated_at'] as String).toLocal();
      final isRecent = now.difference(updatedAt).inSeconds < 5;
      return r['user_id'] != currentUserId && isRecent;
    })
        .map((r) => r['user_name'] as String? ?? 'Someone')
        .toList();
  });
});
// ── Signed URL for a chat attachment (private bucket) ───────────────────────
// messages.attachment_url holds either a storage path ("{groupId}/{file}",
// new messages) or an old public URL (messages sent before the bucket became
// private). Both are turned into the storage path, then into a signed URL
// that only works for group members and expires after 1 hour.
const _chatAttachmentsBucket = 'chat-attachments';
const _signedUrlExpirySeconds = 60 * 60;

String chatAttachmentPath(String stored) =>
    storagePathFromUrl(stored, _chatAttachmentsBucket) ?? stored;

Future<String> createChatAttachmentUrl(String stored) {
  return SupabaseConfig.client.storage
      .from(_chatAttachmentsBucket)
      .createSignedUrl(chatAttachmentPath(stored), _signedUrlExpirySeconds);
}

// autoDispose: a signed URL expires, so don't keep it after the bubble that
// shows it is gone — the next time it is shown, a fresh URL is created.
final attachmentSignedUrlProvider =
FutureProvider.autoDispose.family<String, String>((ref, stored) {
  return createChatAttachmentUrl(stored);
});
