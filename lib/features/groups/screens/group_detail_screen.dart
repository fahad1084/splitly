import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../expenses/controllers/expenses_controller.dart';
import '../../expenses/screens/add_expense_sheet.dart';
import '../../expenses/screens/expense_tile.dart';
import '../controllers/groups_controller.dart';
import '../models/group_model.dart';
import '../../balances/controllers/balances_controller.dart';
import 'package:flutter/services.dart';

class GroupDetailScreen extends ConsumerWidget {
  final GroupModel group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = isDark(context);
    final headingColor = dark ? AppColors.primaryTint : AppColors.primaryDark;

    // ── Watch data ──────────────────────────────────────────────────────────
    final membersAsync = ref.watch(groupMembersProvider(group.id));
    final expensesAsync = ref.watch(expensesProvider(group.id));
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // ── App Bar ─────────────────────────────────────────────────────────
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
        title: Column(
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
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined,
                color: AppColors.primaryTint),
            onPressed: () => _showInviteDialog(context),
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

            // ── Balance summary card ──────────────────────────────────────
            SliverToBoxAdapter(
              child: _BalanceSummaryCard(group: group),
            ),

            // ── Members header ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Members',
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

            // ── Members list ──────────────────────────────────────────────
            membersAsync.when(
              data: (members) => SliverList(
                delegate: SliverChildBuilderDelegate(
                      (_, i) => _MemberTile(member: members[i]),
                  childCount: members.length,
                ),
              ),
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2)),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Could not load members',
                      style: TextStyle(color: AppColors.danger)),
                ),
              ),
            ),

            // ── Expenses header ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Expenses',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: headingColor)),
                    TextButton.icon(
                      onPressed: () =>
                          showAddExpenseSheet(context, group),
                      icon: Icon(Icons.add,
                          size: 16, color: AppColors.primary),
                      label: Text('Add',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.primary)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Expenses list or empty state ──────────────────────────────
            expensesAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2)),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Could not load expenses: $e',
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
                      (_, i) => ExpenseTile(
                    expense: expenses[i],
                    currentUserId: currentUserId,
                    onDelete: () => ref
                        .read(expensesProvider(group.id).notifier)
                        .deleteExpense(expenses[i].id),
                  ),
                  childCount: expenses.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),

      // ── FAB ──────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddExpenseSheet(context, group),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.primaryDark,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense',
            style: TextStyle(fontWeight: FontWeight.w500)),
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite Members'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share this invite code with your friends.\nThey can enter it in the app to join this group.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            // Invite code box with copy button
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: group.inviteCode));
                Navigator.pop(ctx);
                showSuccessSnack(context, 'Invite code copied!');
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primaryLight, width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.inviteCode.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryDark,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.copy_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Tap to copy',
                style: TextStyle(
                    fontSize: 11, color: AppColors.primaryLight),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  void _showGroupMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark(context) ? AppColors.primaryDark : Colors.white,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.archive_outlined,
                  color: AppColors.primary),
              title: const Text('Archive Group'),
              onTap: () async {
                Navigator.pop(context);
                await ref
                    .read(groupsProvider.notifier)
                    .archiveGroup(group.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined,
                  color: AppColors.primary),
              title: const Text('Share Invite Code'),
              onTap: () {
                Navigator.pop(context);
                _showInviteDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BALANCE SUMMARY CARD — now shows real data from expenses
// ─────────────────────────────────────────────────────────────────────────────
class _BalanceSummaryCard extends ConsumerWidget {
  final GroupModel group;
  const _BalanceSummaryCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch expenses so card updates when expenses change
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
          Text(
            group.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryTint,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BalanceItem(
                  label: 'Total spent',
                  value: '${group.currency} ${summary.totalSpent.toStringAsFixed(0)}',
                  color: AppColors.primaryLight,
                ),
              ),
              Expanded(
                child: _BalanceItem(
                  label: 'You are owed',
                  value: '${group.currency} ${summary.youAreOwed.toStringAsFixed(0)}',
                  color: AppColors.success,
                ),
              ),
              Expanded(
                child: _BalanceItem(
                  label: 'You owe',
                  value: '${group.currency} ${summary.youOwe.toStringAsFixed(0)}',
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

// ─────────────────────────────────────────────────────────────────────────────
// MEMBER TILE
// ─────────────────────────────────────────────────────────────────────────────
class _MemberTile extends StatelessWidget {
  final Map<String, dynamic> member;
  const _MemberTile({required this.member});

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final profile = member['profiles'] as Map<String, dynamic>? ?? {};
    final name = profile['full_name'] as String? ?? 'Unknown';
    final avatarColor =
        profile['avatar_color'] as String? ?? '#0F766E';
    final role = member['role'] as String? ?? 'member';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Admin',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryDark)),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPENSES EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _ExpensesEmptyState extends StatelessWidget {
  final GroupModel group;
  const _ExpensesEmptyState({required this.group});

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color:
                dark ? AppColors.primaryDark : AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long_outlined,
                  size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('No expenses yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: dark
                        ? AppColors.primaryTint
                        : AppColors.primaryDark)),
            const SizedBox(height: 8),
            Text(
              'Add the first expense to start tracking who owes what.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.primary, height: 1.5),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}