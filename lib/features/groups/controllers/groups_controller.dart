import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../../core/utils/string_utils.dart';
import '../../balances/controllers/balances_controller.dart';
import '../models/group_model.dart';
import 'dart:io';
import 'package:splitly/core/utils/app_logger.dart';

final groupsProvider =
AsyncNotifierProvider<GroupsController, List<GroupModel>>(
  GroupsController.new,
);

// ── Unread message counts per group (for badges on the groups list) ────────
final unreadCountsProvider =
FutureProvider<Map<String, int>>((ref) async {
  try {
    final List<dynamic> rows =
    await SupabaseConfig.client.rpc('get_unread_counts');
    final result = {
      for (final r in rows)
        r['group_id'] as String: (r['unread_count'] as num).toInt(),
    };
    return result;
  } catch (e) {
    logDebug('=== FETCH UNREAD COUNTS ERROR: $e ===');
    return {};
  }
});

// ── Archived groups (for the "Archived Groups" screen) ──────────────────────
final archivedGroupsProvider =
FutureProvider<List<GroupModel>>((ref) async {
  final db = SupabaseConfig.client;
  final userId = db.auth.currentUser?.id;
  if (userId == null) return [];
  try {
    final List<dynamic> memberRows = await db
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId);
    final groupIds =
    memberRows.map((r) => r['group_id'] as String).toList();
    if (groupIds.isEmpty) return [];

    final List<dynamic> groupRows = await db
        .from('groups')
        .select('*')
        .inFilter('id', groupIds)
        .eq('is_archived', true)
        .order('created_at', ascending: false);

    return groupRows
        .map((r) => GroupModel.fromMap({
      ...Map<String, dynamic>.from(r),
      'member_count': 0, // not needed on this screen
    }))
        .toList();
  } catch (e) {
    logDebug('=== FETCH ARCHIVED GROUPS ERROR: $e ===');
    return [];
  }
});

class GroupsController extends AsyncNotifier<List<GroupModel>> {
  SupabaseClient get _db => SupabaseConfig.client;

  @override
  Future<List<GroupModel>> build() async {
    return _fetchGroups();
  }

  Future<List<GroupModel>> _fetchGroups() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      // Get group IDs user belongs to
      final List<dynamic> memberRows = await _db
          .from('group_members')
          .select('group_id')
          .eq('user_id', userId);


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

      return result;
    } catch (e, st) {
      logDebug('=== FETCH GROUPS ERROR: $e ===');
      logDebug('=== STACK: $st ===');
      rethrow;
    }
  }

  Future<String?> createGroup({
    required String name,
    String? description,
    required String currency,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return 'Not signed in';

    try {
      // ONE call: the group and the creator's admin membership are saved
      // in a single database transaction — never a group with no members.
      await _db.rpc('create_group', params: {
        'p_name': name.trim(),
        'p_description':
        (description?.trim().isEmpty ?? true) ? null : description?.trim(),
        'p_currency': currency,
      });

      state = AsyncValue.data(await _fetchGroups());
      return null;
    } catch (e, st) {
      logDebug('=== CREATE GROUP ERROR: $e ===');
      logDebug('=== STACK: $st ===');
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

  Future<void> unarchiveGroup(String groupId) async {
    await _db
        .from('groups')
        .update({'is_archived': false})
        .eq('id', groupId);
    state = AsyncValue.data(await _fetchGroups());
  }

  Future<String?> deleteGroupPermanently(String groupId) async {
    try {
      await _db.rpc('delete_group_permanently',
          params: {'p_group_id': groupId});
      return null;
    } catch (e) {
      logDebug('=== DELETE GROUP ERROR: $e ===');
      return 'Error: $e';
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    ref.invalidate(myDebtsProvider); // pull-to-refresh reloads balances too
    try {
      state = AsyncValue.data(await _fetchGroups());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ── Remove a member from group (admin only) ────────────────────────────
  Future<String?> removeMember(String groupId, String userId) async {
    try {
      await _db
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);
      return null;
    } catch (e) {
      logDebug('=== REMOVE MEMBER ERROR: $e ===');
      return 'Failed to remove member: $e';
    }
  }

  // ── Leave a group (current user removes self) ───────────────────────────
  // Through leave_group(): the database refuses while you still owe or are
  // owed money in this group. Returns null on success, or an error code
  // ('HAS_UNSETTLED_DEBTS', ... see settleErrorCode).
  Future<String?> leaveGroup(String groupId) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return 'UNKNOWN';
    try {
      await _db.rpc('leave_group', params: {'p_group_id': groupId});
      await refresh();
      return null;
    } on PostgrestException catch (e) {
      logDebug('=== LEAVE GROUP ERROR: ${e.message} ===');
      return settleErrorCode(e.message);
    } catch (e) {
      logDebug('=== LEAVE GROUP ERROR: $e ===');
      return 'UNKNOWN';
    }
  }

  // ── Promote/demote a member's role ──────────────────────────────────────
  Future<String?> setMemberRole(
      String groupId, String userId, String role) async {
    try {
      await _db
          .from('group_members')
          .update({'role': role})
          .eq('group_id', groupId)
          .eq('user_id', userId);
      return null;
    } catch (e) {
      logDebug('=== SET MEMBER ROLE ERROR: $e ===');
      return 'Failed to update role: $e';
    }
  }

  // ── Update group photo ───────────────────────────────────────────────────
  // Each upload gets a NEW file name, so if saving the row fails we can
  // delete just the new file without touching the photo the group already
  // has. After success the old file is removed (best effort).
  Future<String?> updateGroupPhoto(String groupId, File imageFile) async {
    const bucket = 'group-photos';
    String? uploadedPath;
    try {
      final current = await _db
          .from('groups')
          .select('photo_url')
          .eq('id', groupId)
          .maybeSingle();
      final oldPath =
      storagePathFromUrl(current?['photo_url'] as String?, bucket);

      final ext = imageFile.path.split('.').last;
      final path =
          '$groupId/photo_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _db.storage.from(bucket).upload(path, imageFile);
      uploadedPath = path;

      final url = _db.storage.from(bucket).getPublicUrl(path);
      // .select() so we can tell "0 rows updated" (not allowed) from success
      final List<dynamic> updated = await _db
          .from('groups')
          .update({'photo_url': url})
          .eq('id', groupId)
          .select('id');
      if (updated.isEmpty) throw Exception('Group photo not updated');

      if (oldPath != null && oldPath != path) {
        try {
          await _db.storage.from(bucket).remove([oldPath]);
        } catch (_) {}
      }

      state = AsyncValue.data(await _fetchGroups());
      return null;
    } catch (e) {
      logDebug('=== UPDATE GROUP PHOTO ERROR: $e ===');
      if (uploadedPath != null) {
        try {
          await _db.storage.from(bucket).remove([uploadedPath]);
        } catch (_) {}
      }
      return 'Failed to update photo: $e';
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
    logDebug('=== groupDetailProvider ERROR: $e ===');
    rethrow;
  }
});



final groupMembersProvider =
FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, groupId) async {
      try {
        final List<dynamic> resp = await SupabaseConfig.client
            .from('group_members')
            .select('*, profiles(id, full_name, avatar_color, avatar_url, phone)')
            .eq('group_id', groupId);

        return resp.map((r) => Map<String, dynamic>.from(r)).toList();
      } catch (e) {
        logDebug('=== groupMembersProvider ERROR: $e ===');
        rethrow;
      }
    });