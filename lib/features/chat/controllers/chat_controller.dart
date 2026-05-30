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

  // ── Fetch messages with sender names ─────────────────────────────────────
  Future<List<MessageModel>> _fetchMessages() async {
    try {
      final List<dynamic> rows = await SupabaseConfig.client
          .from('messages')
          .select('*')
          .eq('group_id', _groupId)
          .order('created_at', ascending: true)
          .limit(100);

      if (rows.isEmpty) return [];

      // Fetch sender names
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

      return rows.map((r) {
        return MessageModel.fromMap({
          ...Map<String, dynamic>.from(r),
          'sender_name': nameMap[r['sender_id']] ?? 'Unknown',
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

  // ── Send message ──────────────────────────────────────────────────────────
  Future<String?> sendMessage(String content) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return 'Not signed in';
    if (content.trim().isEmpty) return null;

    try {
      await SupabaseConfig.client.from('messages').insert({
        'id': const Uuid().v4(),
        'group_id': _groupId,
        'sender_id': userId,
        'content': content.trim(),
      });
      return null;
    } catch (e) {
      print('=== SEND MESSAGE ERROR: $e ===');
      return 'Failed to send message';
    }
  }
}