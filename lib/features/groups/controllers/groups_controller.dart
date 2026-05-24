import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../config/supabase/supabase_config.dart';
import '../models/group_model.dart';

final groupsProvider =
AsyncNotifierProvider<GroupsController, List<GroupModel>>(
  GroupsController.new,
);

class GroupsController extends AsyncNotifier<List<GroupModel>> {
  SupabaseClient get _db => SupabaseConfig.client;

  @override
  Future<List<GroupModel>> build() async {
    return _fetchGroups();
  }

  Future<List<GroupModel>> _fetchGroups() async {
    final userId = _db.auth.currentUser?.id;
    print('=== FETCH GROUPS userId=$userId ===');
    if (userId == null) return [];

    try {
      // Get group IDs user belongs to
      final List<dynamic> memberRows = await _db
          .from('group_members')
          .select('group_id')
          .eq('user_id', userId);

      print('=== memberRows=$memberRows ===');

      if (memberRows.isEmpty) return [];

      final groupIds =
      memberRows.map((r) => r['group_id'] as String).toList();

      // Fetch groups
      final List<dynamic> groupRows = await _db
          .from('groups')
          .select('*')
          .inFilter('id', groupIds)
          .eq('is_archived', false)
          .order('created_at', ascending: false);

      print('=== groupRows=$groupRows ===');

      // Count members per group
      final List<dynamic> countRows = await _db
          .from('group_members')
          .select('group_id')
          .inFilter('group_id', groupIds);

      final countMap = <String, int>{};
      for (final r in countRows) {
        final id = r['group_id'] as String;
        countMap[id] = (countMap[id] ?? 0) + 1;
      }

      final result = groupRows.map((g) {
        return GroupModel.fromMap({
          ...Map<String, dynamic>.from(g),
          'member_count': countMap[g['id']] ?? 0,
        });
      }).toList();

      print('=== FETCH GROUPS result count=${result.length} ===');
      return result;
    } catch (e, st) {
      print('=== FETCH GROUPS ERROR: $e ===');
      print('=== STACK: $st ===');
      rethrow;
    }
  }

  Future<String?> createGroup({
    required String name,
    String? description,
    required String currency,
  }) async {
    final userId = _db.auth.currentUser?.id;
    print('=== CREATE GROUP userId=$userId ===');
    if (userId == null) return 'Not signed in';

    try {
      // Generate UUID in Flutter — no need to fetch it back after insert
      // This avoids the SELECT policy blocking the fetch
      final groupId = const Uuid().v4();
      print('=== CREATE GROUP: generated groupId=$groupId ===');

      // Step 1 — insert group with our own UUID
      print('=== CREATE GROUP: inserting into groups table ===');
      await _db.from('groups').insert({
        'id': groupId,
        'name': name.trim(),
        'description':
        (description?.trim().isEmpty ?? true) ? null : description?.trim(),
        'currency': currency,
        'created_by': userId,
      });
      print('=== CREATE GROUP: group inserted ===');

      // Step 2 — add creator as admin member
      print('=== CREATE GROUP: inserting into group_members table ===');
      await _db.from('group_members').insert({
        'group_id': groupId,
        'user_id': userId,
        'role': 'admin',
      });
      print('=== CREATE GROUP: success ===');

      state = AsyncValue.data(await _fetchGroups());
      return null;
    } catch (e, st) {
      print('=== CREATE GROUP ERROR: $e ===');
      print('=== STACK: $st ===');
      return 'Error: $e';
    }
  }

  Future<void> archiveGroup(String groupId) async {
    await _db
        .from('groups')
        .update({'is_archived': true})
        .eq('id', groupId);
    state = AsyncValue.data(await _fetchGroups());
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _fetchGroups());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final groupDetailProvider =
FutureProvider.family<GroupModel?, String>((ref, groupId) async {
  final db = SupabaseConfig.client;
  try {
    final dynamic resp = await db
        .from('groups')
        .select('*')
        .eq('id', groupId)
        .single();

    final List<dynamic> countResp = await db
        .from('group_members')
        .select('id')
        .eq('group_id', groupId);

    return GroupModel.fromMap({
      ...Map<String, dynamic>.from(resp),
      'member_count': countResp.length,
    });
  } catch (e) {
    print('=== groupDetailProvider ERROR: $e ===');
    rethrow;
  }
});

final groupMembersProvider =
FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, groupId) async {
      try {
        final List<dynamic> resp = await SupabaseConfig.client
            .from('group_members')
            .select('*, profiles(id, full_name, avatar_color, phone)')
            .eq('group_id', groupId);

        return resp.map((r) => Map<String, dynamic>.from(r)).toList();
      } catch (e) {
        print('=== groupMembersProvider ERROR: $e ===');
        rethrow;
      }
    });