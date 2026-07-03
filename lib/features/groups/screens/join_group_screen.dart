import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/groups_controller.dart';

// ── Provider to join a group ──────────────────────────────────────────────────
final joinGroupProvider =
StateNotifierProvider<JoinGroupController, AsyncValue<void>>(
      (ref) => JoinGroupController(ref),
);

class JoinGroupController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  JoinGroupController(this._ref) : super(const AsyncValue.data(null));

  Future<String?> joinGroup(String inviteCode) async {
    state = const AsyncValue.loading();
    try {
      final userId =
          SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) return 'Not signed in';

      // Find group by invite code
      final List<dynamic> groups = await SupabaseConfig.client
          .from('groups')
          .select('id, name')
          .eq('invite_code', inviteCode.trim().toLowerCase())
          .eq('is_archived', false);

      if (groups.isEmpty) {
        state = const AsyncValue.data(null);
        return 'INVALID_CODE'; // handled in UI with l10n
      }

      final groupId = groups.first['id'] as String;
      final groupName = groups.first['name'] as String;

      // Check if already a member
      final List<dynamic> existing = await SupabaseConfig.client
          .from('group_members')
          .select('id')
          .eq('group_id', groupId)
          .eq('user_id', userId);

      if (existing.isNotEmpty) {
        state = const AsyncValue.data(null);
        return 'ALREADY_MEMBER::$groupName'; // handled in UI with l10n
      }

      // Join the group
      await SupabaseConfig.client.from('group_members').insert({
        'group_id': groupId,
        'user_id': userId,
        'role': 'member',
      });

      // Refresh groups list
      await _ref.read(groupsProvider.notifier).refresh();

      state = const AsyncValue.data(null);
      return null; // success
    } catch (e) {
      print('=== JOIN GROUP ERROR: $e ===');
      state = const AsyncValue.data(null);
      return 'Error: $e';
    }
  }
}

// ── Join Group Sheet ──────────────────────────────────────────────────────────
void showJoinGroupSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _JoinGroupSheet(),
  );
}

class _JoinGroupSheet extends ConsumerStatefulWidget {
  const _JoinGroupSheet();

  @override
  ConsumerState<_JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends ConsumerState<_JoinGroupSheet> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final l10n = AppLocalizations.of(context)!;
    if (_codeCtrl.text.trim().isEmpty) {
      showErrorSnack(context, l10n.pleaseEnterInviteCode);
      return;
    }
    setState(() => _isLoading = true);

    final error = await ref
        .read(joinGroupProvider.notifier)
        .joinGroup(_codeCtrl.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      // ── Translate internal error codes to localized messages ──────
      if (error == 'INVALID_CODE') {
        showErrorSnack(context, l10n.invalidInviteCode);
      } else if (error.startsWith('ALREADY_MEMBER::')) {
        final groupName = error.split('::').last;
        showErrorSnack(context, l10n.alreadyMemberOf(groupName));
      } else {
        showErrorSnack(context, error);
      }
    } else {
      showSuccessSnack(context, l10n.youJoinedGroup);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final sheetBg = dark ? const Color(0xFF042F2E) : Colors.white;
    final headingColor =
    dark ? AppColors.primaryTint : AppColors.primaryDark;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Icon
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: dark
                    ? AppColors.primaryDark
                    : AppColors.primaryTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.group_add_rounded,
                color: AppColors.primary,
                size: 26,
              ),
            ),

            const SizedBox(height: 16),

            Text(l10n.joinAGroupTitle,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: headingColor,
                    letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text(
                l10n.enterInviteCodeDesc,
                style: TextStyle(
                    fontSize: 13, color: AppColors.primary)),

            const SizedBox(height: 24),

            // Code input
            TextFormField(
              controller: _codeCtrl,
              autofocus: true,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.none,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: headingColor,
                letterSpacing: 4,
              ),
              decoration: InputDecoration(
                hintText: 'a1b2c3d4',
                hintStyle: TextStyle(
                  fontSize: 20,
                  color: AppColors.primaryLight.withOpacity(0.4),
                  letterSpacing: 4,
                ),
                labelText: l10n.inviteCode,
                labelStyle:
                const TextStyle(color: AppColors.primary),
              ),
            ),

            const SizedBox(height: 28),

            SplitlyButton(
              label: l10n.joinGroup,
              isLoading: _isLoading,
              onPressed: _join,
              icon: Icons.login_rounded,
            ),
          ],
        ),
      ),
    );
  }
}