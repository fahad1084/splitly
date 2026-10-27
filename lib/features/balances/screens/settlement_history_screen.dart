import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../groups/models/group_model.dart';
import '../controllers/balances_controller.dart';
import '../models/balance_model.dart';
import '../../../core/utils/money_format.dart';

// ── Payment history of one group ──────────────────────────────────────────────
// Who paid whom, how much, when, and the status. The receiver of a pending
// payment can confirm it; either person can cancel it.
class SettlementHistoryScreen extends ConsumerWidget {
  final GroupModel group;
  const SettlementHistoryScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settlementsAsync = ref.watch(settlementsProvider(group.id));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryTint),
        title: Text(
          l10n.payments,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryTint,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(myDebtsProvider);
          ref.invalidate(settlementsProvider(group.id));
          await ref.read(settlementsProvider(group.id).future);
        },
        child: settlementsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 16),
            child: ShimmerList(),
          ),
          error: (_, __) => ListView(children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(l10n.somethingWentWrong,
                    style: const TextStyle(color: AppColors.danger)),
              ),
            ),
          ]),
          data: (settlements) {
            if (settlements.isEmpty) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Text(l10n.noPaymentsYet,
                        style: const TextStyle(color: AppColors.primaryLight)),
                  ),
                ),
              ]);
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: settlements.length,
              itemBuilder: (_, i) => _SettlementTile(settlement: settlements[i]),
            );
          },
        ),
      ),
    );
  }
}

class _SettlementTile extends ConsumerStatefulWidget {
  final SettlementModel settlement;
  const _SettlementTile({required this.settlement});

  @override
  ConsumerState<_SettlementTile> createState() => _SettlementTileState();
}

class _SettlementTileState extends ConsumerState<_SettlementTile> {
  bool _busy = false;

  Future<void> _act({required bool confirm}) async {
    final l10n = AppLocalizations.of(context)!;
    final s = widget.settlement;
    setState(() => _busy = true);
    final notifier = ref.read(settleUpProvider.notifier);
    final error = confirm
        ? await notifier.confirmSettlement(s.groupId, s.id)
        : await notifier.cancelSettlement(s.groupId, s.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      showErrorSnack(context, switch (error) {
        'AMOUNT_TOO_HIGH' => l10n.amountMoreThanOwed,
        _ => l10n.somethingWentWrong,
      });
    } else {
      showSuccessSnack(
          context, confirm ? l10n.paymentConfirmed : l10n.paymentCancelled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final s = widget.settlement;
    final me = SupabaseConfig.client.auth.currentUser?.id ?? '';
    final headingColor = dark ? AppColors.primaryTint : AppColors.primaryDark;

    final (statusText, statusColor) = switch (s.status) {
      'pending' => (l10n.statusPending, AppColors.accentDark),
      'cancelled' => (l10n.statusCancelled, AppColors.danger),
      'legacy' => (l10n.statusEarlier, AppColors.primaryLight),
      _ => (l10n.statusConfirmed, AppColors.success),
    };
    final date = DateFormat.yMMMd(l10n.localeName).add_jm().format(s.createdAt.toLocal());
    final canConfirm = s.isPending && s.paidTo == me;
    final canCancel = s.isPending && (s.paidTo == me || s.paidBy == me);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? AppColors.primaryDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dark ? AppColors.primary.withOpacity(0.2) : AppColors.primaryTint,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${s.paidByName} → ${s.paidToName}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: headingColor),
                ),
              ),
              Text(
                formatMoney(s.amount, s.currency),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: s.status == 'cancelled'
                      ? AppColors.primaryLight
                      : AppColors.success,
                  decoration: s.status == 'cancelled'
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(date,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.primaryLight)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusText,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor)),
              ),
            ],
          ),
          if (canConfirm || canCancel) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (canCancel)
                  TextButton(
                    onPressed: _busy ? null : () => _act(confirm: false),
                    child: Text(l10n.cancelPayment,
                        style: const TextStyle(color: AppColors.danger)),
                  ),
                if (canConfirm) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _busy ? null : () => _act(confirm: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: _busy
                        ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : Text(l10n.confirmPayment),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
