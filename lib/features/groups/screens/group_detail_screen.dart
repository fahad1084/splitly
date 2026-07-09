import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../balances/controllers/balances_controller.dart';
import '../../expenses/controllers/expenses_controller.dart';
import '../../expenses/screens/add_expense_sheet.dart';
import '../../expenses/screens/expense_detail_sheet.dart';
import '../../expenses/screens/expense_history_screen.dart';
import '../../expenses/screens/expense_tile.dart';
import '../controllers/groups_controller.dart';
import '../models/group_model.dart';
import '../../expenses/screens/share_summary_sheet.dart';
import '../../expenses/screens/export_sheet.dart';
import '../../reports/screens/reports_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../../core/utils/string_utils.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class GroupDetailScreen extends ConsumerWidget {
  final GroupModel group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final headingColor =
    dark ? AppColors.primaryTint : AppColors.primaryDark;

    final membersAsync = ref.watch(groupMembersProvider(group.id));
    final expensesAsync = ref.watch(expensesProvider(group.id));
    final currentUserId =
        ref.watch(currentUserProvider)?.id ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.primaryTint,
              size: 16,
            ),
          ),
        ),
        title: Row(
          children: [
            GestureDetector(
              onTap: () => _changeGroupPhoto(context, ref),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.3),
                  shape: BoxShape.circle,
                  image: (group.photoUrl != null && group.photoUrl!.isNotEmpty)
                      ? DecorationImage(
                    image: NetworkImage(group.photoUrl!),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: (group.photoUrl == null || group.photoUrl!.isEmpty)
                    ? const Icon(Icons.group_rounded, color: AppColors.primaryTint, size: 18)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryTint)),
                Text(group.currency,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined,
                color: AppColors.primaryTint),
            onPressed: () => _showInviteDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded,
                color: AppColors.primaryTint),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(group: group),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.primaryTint),
            onPressed: () => _showGroupMenu(context, ref),
          ),
        ],
      ),

      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () =>
            ref.read(expensesProvider(group.id).notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [

            // ── Balance summary ───────────────────────────────────────
            SliverToBoxAdapter(
              child: _BalanceSummaryCard(group: group),
            ),

            // ── Members header ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.members,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: headingColor)),
                    membersAsync.when(
                      data: (members) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${members.length}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primaryDark)),
                      ),
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),
                  ],
                ),
              ),
            ),

            // ── Members list ──────────────────────────────────────────
            membersAsync.when(
              data: (members) => SliverList(
                delegate: SliverChildBuilderDelegate(
                      (_, i) => _MemberTile(
                    member: members[i],
                    group: group,
                    isCurrentUserAdmin: members.any((m) =>
                    m['user_id'] == currentUserId && m['role'] == 'admin'),
                  ),
                  childCount: members.length,
                ),
              ),
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: ShimmerList(count: 2),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(l10n.couldNotLoadMembers,
                      style: TextStyle(color: AppColors.danger)),
                ),
              ),
            ),

            // ── Expenses header — with History + Add buttons ──────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.expensesHeading,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: headingColor)),
                    Row(
                      children: [
                        // ✅ History button
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExpenseHistoryScreen(
                                  group: group),
                            ),
                          ),
                          icon: Icon(Icons.history_rounded,
                              size: 16,
                              color: AppColors.primaryLight),
                          label: Text(l10n.history,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primaryLight)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                        ),
                        // Add button
                        TextButton.icon(
                          onPressed: () =>
                              showAddExpenseSheet(context, group),
                          icon: Icon(Icons.add,
                              size: 16, color: AppColors.primary),
                          label: Text(l10n.add,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Expenses list or empty state ──────────────────────────
            expensesAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: ShimmerList(count: 3),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('${l10n.couldNotLoadExpenses}: $e',
                      style: TextStyle(color: AppColors.danger)),
                ),
              ),
              data: (expenses) => expenses.isEmpty
                  ? SliverFillRemaining(
                hasScrollBody: false,
                child: _ExpensesEmptyState(group: group),
              )
                  : SliverList(
                delegate: SliverChildBuilderDelegate(
                      (_, i) => GestureDetector(
                    onTap: () => showExpenseDetailSheet(
                        context, expenses[i], group),
                    child: ExpenseTile(
                      expense: expenses[i],
                      currentUserId: currentUserId,
                      onDelete: () => ref
                          .read(expensesProvider(group.id)
                          .notifier)
                          .deleteExpense(expenses[i].id),
                    ),
                  ),
                  childCount: expenses.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddExpenseSheet(context, group),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.primaryDark,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.addExpense,
            style: const TextStyle(fontWeight: FontWeight.w500)),
      ),
    );
  }

  // ✅ NEW — pick a photo from gallery and update the group's photo
  void _changeGroupPhoto(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 800,
    );
    if (picked == null) return;

    final error = await ref
        .read(groupsProvider.notifier)
        .updateGroupPhoto(group.id, File(picked.path));

    if (!context.mounted) return;
    if (error != null) {
      showErrorSnack(context, l10n.failedToUpdatePhoto);
    } else {
      showSuccessSnack(context, l10n.groupPhotoUpdated);
    }
  }

  void _showInviteDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final sheetBg = dark ? AppColors.primaryDark : Colors.white;
    final textColor = dark ? AppColors.primaryTint : AppColors.primaryDark;
    final codeBg = dark ? AppColors.darkBg : AppColors.primaryTint;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              Text(
                l10n.inviteToGroup(group.name),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.shareCodeDesc,
                style: TextStyle(fontSize: 13, color: AppColors.primary),
              ),
              const SizedBox(height: 24),

              // Invite code display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: codeBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryLight.withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    Text(
                      group.inviteCode,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.inviteCode,
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: group.inviteCode));
                    Navigator.pop(sheetContext);
                    showSuccessSnack(context, l10n.inviteCodeCopied);
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(l10n.copyCode),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _showGroupMenu(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final sheetBg = dark ? AppColors.primaryDark : Colors.white;
    final textColor = dark ? AppColors.primaryTint : AppColors.primaryDark;
    final borderColor = dark ? AppColors.primary.withOpacity(0.3) : AppColors.primaryTint;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                group.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),

            _MenuTile(
              icon: Icons.person_add_outlined,
              iconColor: AppColors.primary,
              label: l10n.shareInviteCode,
              textColor: textColor,
              borderColor: borderColor,
              onTap: () {
                Navigator.pop(sheetContext);
                _showInviteDialog(context);
              },
            ),
            const SizedBox(height: 8),

            _MenuTile(
              icon: Icons.share_outlined,
              iconColor: AppColors.primary,
              label: l10n.shareSummary,
              textColor: textColor,
              borderColor: borderColor,
              onTap: () {
                Navigator.pop(sheetContext);
                showShareSummarySheet(context, group);
              },
            ),
            const SizedBox(height: 8),

            _MenuTile(
              icon: Icons.download_outlined,
              iconColor: AppColors.primary,
              label: l10n.exportPdfCsv,
              textColor: textColor,
              borderColor: borderColor,
              onTap: () {
                Navigator.pop(sheetContext);
                showExportSheet(context, group);
              },
            ),
            const SizedBox(height: 8),

            _MenuTile(
              icon: Icons.exit_to_app_rounded,
              iconColor: AppColors.danger,
              label: l10n.leaveGroup,
              textColor: AppColors.danger,
              borderColor: borderColor,
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmLeaveGroup(context, ref);
              },
            ),

            _MenuTile(
              icon: Icons.bar_chart_rounded,
              iconColor: AppColors.primary,
              label: l10n.spendingReports,
              textColor: textColor,
              borderColor: borderColor,
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                );
              },
            ),
            const SizedBox(height: 8),

            _MenuTile(
              icon: Icons.archive_outlined,
              iconColor: AppColors.danger,
              label: l10n.archiveGroup,
              textColor: AppColors.danger,
              borderColor: borderColor,
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmArchive(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmArchive(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dark ? AppColors.primaryDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.archiveGroupTitle,
          style: TextStyle(color: dark ? AppColors.primaryTint : AppColors.primaryDark),
        ),
        content: Text(
          l10n.archiveGroupDesc,
          style: TextStyle(color: dark ? AppColors.primaryTint.withOpacity(0.8) : AppColors.primaryDark.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel, style: TextStyle(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(groupsProvider.notifier).archiveGroup(group.id);
              if (context.mounted) Navigator.pop(context); // back to groups list
            },
            child: Text(l10n.archive, style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveGroup(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dark ? AppColors.primaryDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.leaveGroup,
            style: TextStyle(color: dark ? AppColors.primaryTint : AppColors.primaryDark)),
        content: Text(l10n.leaveGroupConfirm,
            style: TextStyle(color: dark ? AppColors.primaryTint.withOpacity(0.8) : AppColors.primaryDark.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel, style: TextStyle(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final error = await ref.read(groupsProvider.notifier).leaveGroup(group.id);
              if (context.mounted) {
                if (error != null) {
                  showErrorSnack(context, error);
                } else {
                  showSuccessSnack(context, l10n.youLeftGroup);
                  Navigator.pop(context);
                }
              }
            },
            child: Text(l10n.leave, style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color textColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.textColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.primaryLight, size: 20),
          ],
        ),
      ),
    );
  }
}
// ── Balance Summary Card ──────────────────────────────────────────────────────
class _BalanceSummaryCard extends ConsumerWidget {
  final GroupModel group;
  const _BalanceSummaryCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    ref.watch(expensesProvider(group.id));
    final summary = ref.watch(groupBalanceSummaryProvider({
      'groupId': group.id,
      'groupName': group.name,
      'currency': group.currency,
    }));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.name,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryTint)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BalanceItem(
                  label: l10n.totalSpent,
                  value:
                  '${group.currency} ${summary.totalSpent.toStringAsFixed(0)}',
                  color: AppColors.primaryLight,
                ),
              ),
              Expanded(
                child: _BalanceItem(
                  label: l10n.youAreOwed,
                  value:
                  '${group.currency} ${summary.youAreOwed.toStringAsFixed(0)}',
                  color: AppColors.success,
                ),
              ),
              Expanded(
                child: _BalanceItem(
                  label: l10n.youOwe,
                  value:
                  '${group.currency} ${summary.youOwe.toStringAsFixed(0)}',
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BalanceItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color)),
      ],
    );
  }
}

// ── Member Tile ───────────────────────────────────────────────────────────────
class _MemberTile extends ConsumerWidget {
  final Map<String, dynamic> member;
  final GroupModel group;
  final bool isCurrentUserAdmin;

  const _MemberTile({
    required this.member,
    required this.group,
    required this.isCurrentUserAdmin,
  });

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final profile =
        member['profiles'] as Map<String, dynamic>? ?? {};
    final name = profile['full_name'] as String? ?? 'Unknown';
    final memberUserId = profile['id'] as String? ?? '';
    final avatarColor =
        profile['avatar_color'] as String? ?? '#0F766E';
    final role = member['role'] as String? ?? 'member';
    final initial = getInitial(name);
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
    final isSelf = memberUserId == currentUserId;

    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onLongPress: (isCurrentUserAdmin && !isSelf)
            ? () => _showMemberActions(context, ref, name, memberUserId, role)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: dark ? AppColors.primaryDark : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: dark
                  ? AppColors.primary.withOpacity(0.2)
                  : AppColors.primaryTint,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _parseColor(avatarColor),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: dark
                            ? AppColors.primaryTint
                            : AppColors.primaryDark)),
              ),
              if (role == 'admin')
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(l10n.admin,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryDark)),
                ),
              if (isCurrentUserAdmin && !isSelf)
                Icon(Icons.more_vert_rounded,
                    size: 18, color: AppColors.primaryLight),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemberActions(BuildContext context, WidgetRef ref,
      String name, String memberUserId, String role) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: dark ? AppColors.primaryDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                role == 'admin' ? Icons.remove_moderator_outlined : Icons.admin_panel_settings_outlined,
                color: AppColors.primary,
              ),
              title: Text(role == 'admin' ? l10n.removeAdmin : l10n.makeAdmin),
              onTap: () async {
                Navigator.pop(sheetContext);
                await ref.read(groupsProvider.notifier).setMemberRole(
                    group.id, memberUserId, role == 'admin' ? 'member' : 'admin');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined, color: AppColors.danger),
              title: Text(l10n.removeMember, style: const TextStyle(color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(l10n.removeMember),
                    content: Text(l10n.removeMemberConfirm(name)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: Text(l10n.cancel)),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                        child: Text(l10n.remove),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  final error = await ref
                      .read(groupsProvider.notifier)
                      .removeMember(group.id, memberUserId);
                  if (context.mounted) {
                    if (error != null) {
                      showErrorSnack(context, error);
                    } else {
                      showSuccessSnack(context, l10n.memberRemoved);
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Expenses Empty State ──────────────────────────────────────────────────────
class _ExpensesEmptyState extends StatelessWidget {
  final GroupModel group;
  const _ExpensesEmptyState({required this.group});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 40, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: dark
                    ? AppColors.primaryDark
                    : AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long_outlined,
                  size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(l10n.noExpensesYet,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: dark
                        ? AppColors.primaryTint
                        : AppColors.primaryDark)),
            const SizedBox(height: 8),
            Text(
              l10n.addFirstExpenseDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  height: 1.5),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}