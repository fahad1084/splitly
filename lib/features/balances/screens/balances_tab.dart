import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../balances/controllers/balances_controller.dart';
import '../../balances/models/balance_model.dart';
import '../../balances/screens/settle_up_sheet.dart';
import '../../expenses/controllers/expenses_controller.dart';
import '../../groups/controllers/groups_controller.dart';

class BalancesTab extends ConsumerWidget {
  const BalancesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.balances,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryTint,
          ),
        ),
      ),
      body: groupsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 16),
          child: ShimmerList(),
        ),
        error: (e, _) => Center(
          child: Text('${l10n.somethingWentWrong}: $e',
              style: TextStyle(color: AppColors.danger)),
        ),
        data: (groups) {
          if (groups.isEmpty) return const _EmptyState();

          // ── Pre-load expenses for ALL groups ──────────────────────
          // This ensures balances calculate correctly on first open
          for (final group in groups) {
            ref.watch(expensesProvider(group.id));
          }

          // Build summaries
          final summaries = groups.map((group) {
            return ref.watch(groupBalanceSummaryProvider({
              'groupId': group.id,
              'groupName': group.name,
              'currency': group.currency,
            }));
          }).toList();

          // Overall totals
          double totalOwed = 0;
          double totalOwe = 0;
          final allDebts = <DebtModel>[];

          for (final s in summaries) {
            totalOwed += s.youAreOwed;
            totalOwe += s.youOwe;
            allDebts.addAll(s.debts);
          }

          final currency = groups.first.currency;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () =>
                ref.read(groupsProvider.notifier).refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              slivers: [

                // Overall banner
                SliverToBoxAdapter(
                  child: _OverallBanner(
                    totalOwed: totalOwed,
                    totalOwe: totalOwe,
                    currency: currency,
                  ),
                ),

                // Who owes who section
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                    const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Text(
                      l10n.whoOwesWho,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: dark
                            ? AppColors.primaryTint
                            : AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),

                allDebts.isEmpty
                    ? const SliverToBoxAdapter(
                    child: _SettledState())
                    : SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (_, i) => _DebtTile(
                      debt: allDebts[i],
                      onSettle: () => showSettleUpSheet(
                          context, allDebts[i]),
                    ),
                    childCount: allDebts.length,
                  ),
                ),

                // By group section
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                    const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Text(
                      l10n.byGroup,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: dark
                            ? AppColors.primaryTint
                            : AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),

                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (_, i) =>
                        _GroupBalanceCard(summary: summaries[i]),
                    childCount: summaries.length,
                  ),
                ),

                const SliverToBoxAdapter(
                    child: SizedBox(height: 80)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Overall Banner ────────────────────────────────────────────────────────────
class _OverallBanner extends StatelessWidget {
  final double totalOwed;
  final double totalOwe;
  final String currency;

  const _OverallBanner({
    required this.totalOwed,
    required this.totalOwe,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final net = totalOwed - totalOwe;
    final isPositive = net >= 0;

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
          Text(l10n.overallBalance,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.primaryLight)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currency ${net.abs().toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w500,
                  color: isPositive
                      ? AppColors.success
                      : AppColors.danger,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  isPositive ? l10n.youAreOwedLower : l10n.youOweLower,
                  style: TextStyle(
                    fontSize: 13,
                    color: isPositive
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BannerStat(
                  label: l10n.youAreOwed,
                  value:
                  '$currency ${totalOwed.toStringAsFixed(0)}',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BannerStat(
                  label: l10n.youOwe,
                  value:
                  '$currency ${totalOwe.toStringAsFixed(0)}',
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

class _BannerStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BannerStat(
      {required this.label,
        required this.value,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border:
        Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: AppColors.primaryLight)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }
}

// ── Debt Tile ─────────────────────────────────────────────────────────────────
class _DebtTile extends StatelessWidget {
  final DebtModel debt;
  final VoidCallback onSettle;
  const _DebtTile({required this.debt, required this.onSettle});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final currentUserId =
        SupabaseConfig.client.auth.currentUser?.id ?? '';
    final iAmPaying = debt.fromUserId == currentUserId;
    final iAmReceiving = debt.toUserId == currentUserId;

    return Container(
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
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.danger.withOpacity(0.15),
            child: Text(
              debt.fromUserName[0].toUpperCase(),
              style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: dark
                          ? AppColors.primaryTint
                          : AppColors.primaryDark,
                    ),
                    children: [
                      TextSpan(
                        text: iAmPaying
                            ? l10n.youWord
                            : debt.fromUserName.split(' ').first,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500),
                      ),
                      TextSpan(text: l10n.owesWord),
                      TextSpan(
                        text: iAmReceiving
                            ? l10n.youWordLower
                            : debt.toUserName.split(' ').first,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(debt.groupName,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryLight)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${debt.currency} ${debt.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: iAmPaying
                      ? AppColors.danger
                      : AppColors.success,
                ),
              ),
              const SizedBox(height: 6),
              if (iAmPaying || iAmReceiving)
                GestureDetector(
                  onTap: onSettle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l10n.settleUp,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Group Balance Card ────────────────────────────────────────────────────────
class _GroupBalanceCard extends StatelessWidget {
  final GroupBalanceSummary summary;
  const _GroupBalanceCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.group_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  summary.groupName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: dark
                        ? AppColors.primaryTint
                        : AppColors.primaryDark,
                  ),
                ),
              ),
              Text(
                '${summary.currency} ${summary.totalSpent.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 13, color: AppColors.primaryLight),
              ),
            ],
          ),
          if (summary.youAreOwed > 0 || summary.youOwe > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (summary.youAreOwed > 0)
                  Expanded(
                    child: _GroupStat(
                      label: l10n.owedToYou,
                      value:
                      '${summary.currency} ${summary.youAreOwed.toStringAsFixed(0)}',
                      color: AppColors.success,
                    ),
                  ),
                if (summary.youAreOwed > 0 && summary.youOwe > 0)
                  const SizedBox(width: 8),
                if (summary.youOwe > 0)
                  Expanded(
                    child: _GroupStat(
                      label: l10n.youOwe,
                      value:
                      '${summary.currency} ${summary.youOwe.toStringAsFixed(0)}',
                      color: AppColors.danger,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _GroupStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: AppColors.primaryLight)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }
}

// ── Empty States ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color:
              dark ? AppColors.primaryDark : AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 36,
                color: AppColors.primary),
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
            l10n.createOrJoinGroup,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                color: AppColors.primary,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _SettledState extends StatelessWidget {
  const _SettledState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                size: 36, color: AppColors.success),
          ),
          const SizedBox(height: 16),
          Text(l10n.allSettledUp,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: dark
                      ? AppColors.primaryTint
                      : AppColors.primaryDark)),
          const SizedBox(height: 8),
          Text(
            l10n.noOutstandingBalances,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                color: AppColors.primary,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}