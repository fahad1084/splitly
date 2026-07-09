import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../config/supabase/supabase_config.dart';
import '../models/message_model.dart';

// ── Messages provider per group ───────────────────────────────────────────────
final messagesProvider =
AsyncNotifierProviderFamily<ChatController, List<MessageModel>, String>(
  ChatController.new,
);

class ChatController
    extends FamilyAsyncNotifier<List<MessageModel>, String> {
  String get _groupId => arg;
  RealtimeChannel? _channel;

  @override
  Future<List<MessageModel>> build(String arg) async {
    // Load initial messages
    final messages = await _fetchMessages();

    // Subscribe to realtime new messages
    _subscribeToRealtime();

    // Clean up channel when provider is disposed
    ref.onDispose(() {
      _channel?.unsubscribe();
    });

    return messages;
  }

// ── Fetch messages with sender names + reply info ──────────────────────────
  Future<List<MessageModel>> _fetchMessages() async {
    try {
      final List<dynamic> rows = await SupabaseConfig.client
          .from('messages')
          .select('*')
          .eq('group_id', _groupId)
          .order('created_at', ascending: true)
          .limit(100);

      if (rows.isEmpty) return [];

      final senderIds =
      rows.map((r) => r['sender_id'] as String).toSet().toList();
      final List<dynamic> profiles = await SupabaseConfig.client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', senderIds);

      final nameMap = <String, String>{
        for (final p in profiles)
          p['id'] as String: p['full_name'] as String,
      };

      // Build a lookup for reply-to messages (id → content + sender)
      final byId = <String, Map<String, dynamic>>{
        for (final r in rows) r['id'] as String: Map<String, dynamic>.from(r),
      };

      return rows.map((r) {
        final map = Map<String, dynamic>.from(r);
        final replyToId = map['reply_to_id'] as String?;
        String? replyContent;
        String? replySender;
        if (replyToId != null && byId.containsKey(replyToId)) {
          final replyMsg = byId[replyToId]!;
          replyContent = replyMsg['content'] as String?;
          replySender = nameMap[replyMsg['sender_id']] ?? 'Unknown';
        }

        return MessageModel.fromMap({
          ...map,
          'sender_name': nameMap[r['sender_id']] ?? 'Unknown',
          'reply_to_content': replyContent,
          'reply_to_sender': replySender,
        });
      }).toList();
    } catch (e) {
      print('=== FETCH MESSAGES ERROR: $e ===');
      return [];
    }
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

        // Fetch sender name for new message
        try {
          final profile = await SupabaseConfig.client
              .from('profiles')
              .select('full_name')
              .eq('id', newRow['sender_id'])
              .single();

          final message = MessageModel.fromMap({
            ...newRow,
            'sender_name': profile['full_name'] ?? 'Unknown',
          });

          // Add to current list
          final current = state.value ?? [];
          // Avoid duplicates
          if (!current.any((m) => m.id == message.id)) {
            state = AsyncValue.data([...current, message]);
          }
        } catch (e) {
          print('=== REALTIME MESSAGE ERROR: $e ===');
        }
      },
    )
        .subscribe();
  }

// ── Send text message (with optional reply) ─────────────────────────────
// ── Send text message (with optional reply) ─────────────────────────────
  Future<String?> sendMessage(String content, {String? replyToId}) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return 'Not signed in';
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
    } catch (e) {
      print('=== SEND MESSAGE ERROR: $e ===');
      return 'Failed to send message';
    }
  }
  // ── Delete a message (sender only, enforced by RLS) ─────────────────────
  Future<String?> deleteMessage(String messageId) async {
    try {
      await SupabaseConfig.client.from('messages').delete().eq('id', messageId);
      final current = state.value ?? [];
      state = AsyncValue.data(current.where((m) => m.id != messageId).toList());
      return null;
    } catch (e) {
      return 'Failed to delete message';
    }
  }

  // ── Typing indicator ──────────────────────────────────────────────────────
  Future<void> setTyping(bool isTyping) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      if (isTyping) {
        final profile = await SupabaseConfig.client
            .from('profiles')
            .select('full_name')
            .eq('id', userId)
            .single();

        await SupabaseConfig.client.from('typing_status').upsert({
          'group_id': _groupId,
          'user_id': userId,
          'user_name': profile['full_name'],
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        await SupabaseConfig.client
            .from('typing_status')
            .delete()
            .eq('group_id', _groupId)
            .eq('user_id', userId);
      }
    } catch (_) {}
  }
  // ── Send image attachment ─────────────────────────────────────────────────
// ── Send image attachment ─────────────────────────────────────────────────
  Future<String?> sendImage(File imageFile, {String caption = ''}) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return 'Not signed in';

    try {
      final ext = imageFile.path.split('.').last;
      final fileName = '${const Uuid().v4()}.$ext';
      final path = '$_groupId/$fileName';

      await SupabaseConfig.client.storage
          .from('chat-attachments')
          .upload(path, imageFile);

      final url = SupabaseConfig.client.storage
          .from('chat-attachments')
          .getPublicUrl(path);

      await SupabaseConfig.client.from('messages').insert({
        'id': const Uuid().v4(),
        'group_id': _groupId,
        'sender_id': userId,
        'content': caption,          // ✅ caption goes here now
        'attachment_url': url,
        'attachment_type': 'image',
      });
      return null;
    } catch (e) {
      print('=== SEND IMAGE ERROR: $e ===');
      return 'Failed to send image';
    }
  }


  // ── Send voice message ────────────────────────────────────────────────────
  Future<String?> sendAudio(File audioFile, int durationSeconds) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return 'Not signed in';

    try {
      final fileName = '${const Uuid().v4()}.m4a';
      final path = '$_groupId/$fileName';

      await SupabaseConfig.client.storage
          .from('chat-attachments')
          .upload(path, audioFile);

      final url = SupabaseConfig.client.storage
          .from('chat-attachments')
          .getPublicUrl(path);

      await SupabaseConfig.client.from('messages').insert({
        'id': const Uuid().v4(),
        'group_id': _groupId,
        'sender_id': userId,
        'content': '',
        'attachment_url': url,
        'attachment_type': 'audio',
        'audio_duration': durationSeconds,
      });
      return null;
    } catch (e) {
      print('=== SEND AUDIO ERROR: $e ===');
      return 'Failed to send voice message';
    }
  }
}

// ── Typing status stream — who is currently typing in this group ─────────────
final typingUsersProvider = StreamProvider.family<List<String>, String>((ref, groupId) {
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