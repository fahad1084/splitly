import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../balances/controllers/balances_controller.dart';
import '../controllers/groups_controller.dart';
import '../models/group_model.dart';
import '../screens/create_group_sheet.dart';
import '../screens/group_detail_screen.dart';
import '../screens/join_group_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../notifications/controllers/notifications_controller.dart';
import '../../../core/utils/money_format.dart';

class GroupsTab extends ConsumerWidget {
  const GroupsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final user = ref.watch(currentUserProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final unreadAsync = ref.watch(unreadCountsProvider);
    final unreadCounts = unreadAsync.value ?? {};
    final online = ref.watch(isOnlineProvider).value ?? true;
    final debtsAsync = ref.watch(myDebtsProvider);
    final debtsFailed = online && debtsAsync.hasError && !debtsAsync.hasValue;
    final userName =
        user?.userMetadata?['full_name'] as String? ?? 'there';
    final firstName = userName.split(' ').first;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: const CustomPaint(painter: SBlobPainter()),
            ),
            const SizedBox(width: 10),
            Text(
              'Splitly',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryTint,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined,
                color: AppColors.primaryTint),
            tooltip: l10n.joinAGroup,
            onPressed: () => showJoinGroupSheet(context),
          ),
          Builder(
            builder: (_) {
              final unreadCount =
                  ref.watch(unreadNotificationCountProvider).value ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: AppColors.primaryTint),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()),
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: groupsAsync.when(
        skipError: true, // keep the last data if a reload fails
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 16),
          child: ShimmerList(),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  color: AppColors.danger, size: 40),
              const SizedBox(height: 12),
              Text(l10n.somethingWentWrong,
                  style: TextStyle(color: AppColors.dangerText(context))),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.read(groupsProvider.notifier).refresh(),
                child: Text(l10n.tryAgain),
              ),
            ],
          ),
        ),
        data: (groups) {
          // ── Balances across all groups, PER CURRENCY ───────────
          // (never add PKR and USD together)
          final owed = <String, int>{};
          final owe = <String, int>{};
          final currency =
          groups.isEmpty ? 'PKR' : groups.first.currency;

          for (final group in groups) {
            final summary = ref.watch(groupDebtSummaryProvider(group.balanceKey));
            addToTotals(owed, group.currency, summary.youAreOwed);
            addToTotals(owe, group.currency, summary.youOwe);
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () =>
                ref.read(groupsProvider.notifier).refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              slivers: [
                // Something small failed → a thin bar, the list still works
                if (debtsFailed)
                  SliverToBoxAdapter(
                    child: ErrorBanner(
                      message: l10n.couldNotLoadBalances,
                      onRetry: () => ref.invalidate(myDebtsProvider),
                    ),
                  ),
                if (online && unreadAsync.hasError && !unreadAsync.hasValue)
                  SliverToBoxAdapter(
                    child: ErrorBanner(
                      message: l10n.couldNotLoadUnread,
                      onRetry: () => ref.invalidate(unreadCountsProvider),
                    ),
                  ),

                // Summary banner with real data
                SliverToBoxAdapter(
                  child: _SummaryBanner(
                    firstName: firstName,
                    owed: owed,
                    owe: owe,
                    currency: currency,
                  ),
                ),

                // Section header
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                    const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.yourGroups,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: dark
                                ? AppColors.primaryTint
                                : AppColors.primaryDark,
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  showJoinGroupSheet(context),
                              child: Container(
                                padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5),
                                decoration: BoxDecoration(
                                  color: dark
                                      ? AppColors.primaryDark
                                      : AppColors.primaryTint,
                                  borderRadius:
                                  BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppColors.primaryLight,
                                      width: 0.5),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.login_rounded,
                                        size: 13,
                                        color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(l10n.join,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.primary,
                                            fontWeight:
                                            FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () =>
                                  showCreateGroupSheet(context),
                              child: Container(
                                padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius:
                                  BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.add_rounded,
                                        size: 13,
                                        color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(l10n.newButton,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight:
                                            FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Groups list or empty state
                groups.isEmpty
                    ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyGroupsState(
                    onCreateTap: () =>
                        showCreateGroupSheet(context),
                    onJoinTap: () =>
                        showJoinGroupSheet(context),
                  ),
                )
                    : SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (_, i) => _GroupCard(
                      group: groups[i],
                      unreadCount: unreadCounts[groups[i].id] ?? 0,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupDetailScreen(
                            group: groups[i],
                          ),
                        ),
                      ),
                    ),
                    childCount: groups.length,
                  ),
                ),

                const SliverToBoxAdapter(
                    child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateGroupSheet(context),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.primaryDark,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.newGroup,
            style: const TextStyle(fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// ── Group Card ────────────────────────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  final GroupModel group;
  final int unreadCount;
  final VoidCallback onTap;
  const _GroupCard(
      {required this.group, required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark ? AppColors.primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: dark
                ? AppColors.primary.withOpacity(0.2)
                : AppColors.primaryTint,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(14),
                    image: (group.photoUrl != null && group.photoUrl!.isNotEmpty)
                        ? DecorationImage(
                      image: NetworkImage(group.photoUrl!),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: (group.photoUrl == null || group.photoUrl!.isEmpty)
                      ? Icon(groupTypeIcon(group.category),
                      color: AppColors.primary, size: 24)
                      : null,
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      constraints:
                      const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: dark ? AppColors.primaryDark : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: dark
                          ? AppColors.primaryTint
                          : AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.people_outline_rounded,
                          size: 12, color: AppColors.primaryLight),
                      const SizedBox(width: 4),
                      Text(l10n.membersCount(group.memberCount ?? 0),
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedText(context))),
                      const SizedBox(width: 10),
                      Icon(groupTypeIcon(group.category),
                          size: 13,
                          color: AppColors.primaryLight,
                          semanticLabel: groupTypeLabel(l10n, group.category)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(group.currency,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primaryDark)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.primaryLight),
          ],
        ),
      ),
    );
  }
}

// ── Summary Banner with real balance data ─────────────────────────────────────
class _SummaryBanner extends StatelessWidget {
  final String firstName;
  final Map<String, int> owed; // paisa per currency
  final Map<String, int> owe;
  final String currency; // shown when there is nothing at all

  const _SummaryBanner({
    required this.firstName,
    required this.owed,
    required this.owe,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          Text(l10n.hey(firstName) + ' 👋',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryTint)),
          const SizedBox(height: 4),
          Text(l10n.balanceSummary,
              style: TextStyle(
                  fontSize: 13, color: AppColors.primaryTint)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _BalanceCard(
                  label: l10n.youAreOwed,
                  // One line per currency
                  amount: formatTotals(owed,
                      fallbackCurrency: currency, separator: '\n'),
                  color: AppColors.successOnDark,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BalanceCard(
                  label: l10n.youOwe,
                  amount: formatTotals(owe,
                      fallbackCurrency: currency, separator: '\n'),
                  color: AppColors.dangerOnDark,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final IconData icon;
  const _BalanceCard(
      {required this.label,
        required this.amount,
        required this.color,
        required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border:
        Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.primaryTint)),
            ],
          ),
          const SizedBox(height: 10),
          Text(amount,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyGroupsState extends StatelessWidget {
  final VoidCallback onCreateTap;
  final VoidCallback onJoinTap;
  const _EmptyGroupsState(
      {required this.onCreateTap, required this.onJoinTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: dark
                    ? AppColors.primaryDark
                    : AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group_outlined,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(l10n.noGroupsYet,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: dark
                        ? AppColors.primaryTint
                        : AppColors.primaryDark)),
            const SizedBox(height: 8),
            Text(
              l10n.createFirstGroupDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  height: 1.5),
            ),
            const SizedBox(height: 28),
            SplitlyButton(
              label: l10n.createGroup,
              onPressed: onCreateTap,
              icon: Icons.add_rounded,
            ),
            const SizedBox(height: 12),
            SplitlyButton(
              label: l10n.joinWithInviteCode,
              onPressed: onJoinTap,
              isOutline: true,
              icon: Icons.login_rounded,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}