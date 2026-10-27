import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../groups/controllers/groups_controller.dart';
import '../../groups/models/group_model.dart';
import '../controllers/expenses_controller.dart';
import '../models/expense_model.dart';
import 'expense_detail_sheet.dart';
import '../../../core/utils/money_format.dart';

// ── Recurring expenses of one group ───────────────────────────────────────────
// Each one with how often it repeats and the next day a copy is added (by
// the daily job on the server). The creator, the payer or a group admin can
// pause, resume or stop it.
class RecurringExpensesScreen extends ConsumerWidget {
  final GroupModel group;
  const RecurringExpensesScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final expensesAsync = ref.watch(expensesProvider(group.id));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryTint),
        title: Text(
          l10n.recurringExpenses,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryTint,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(expensesProvider(group.id).notifier).refresh(),
        child: expensesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 16),
            child: ShimmerList(),
          ),
          // A ListView, so pull-to-refresh still works on the error too
          error: (_, __) => ListView(children: [
            ErrorRetry(
              onRetry: () => ref.invalidate(expensesProvider(group.id)),
            ),
          ]),
          data: (expenses) {
            final recurring = expenses.where((e) => e.isRecurring).toList();
            if (recurring.isEmpty) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Text(l10n.noRecurringExpenses,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.primaryLight)),
                  ),
                ),
              ]);
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: recurring.length,
              itemBuilder: (_, i) =>
                  _RecurringTile(expense: recurring[i], group: group),
            );
          },
        ),
      ),
    );
  }
}

class _RecurringTile extends ConsumerStatefulWidget {
  final ExpenseModel expense;
  final GroupModel group;
  const _RecurringTile({required this.expense, required this.group});

  @override
  ConsumerState<_RecurringTile> createState() => _RecurringTileState();
}

class _RecurringTileState extends ConsumerState<_RecurringTile> {
  bool _busy = false;

  Future<void> _act(String action) async {
    final l10n = AppLocalizations.of(context)!;
    final e = widget.expense;

    if (action == 'stop') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.stopRepeating),
          content: Text(l10n.stopRepeatingConfirm(e.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: Text(l10n.stopRepeating),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _busy = true);
    final error = await ref
        .read(expensesProvider(widget.group.id).notifier)
        .setRecurringStatus(e.id, action);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      showErrorSnack(context, switch (error) {
        'NOT_ALLOWED' => l10n.onlyPayerOrAdminCanEdit,
        _ => l10n.somethingWentWrong,
      });
    } else {
      showSuccessSnack(context, switch (action) {
        'pause' => l10n.recurringPausedMsg,
        'resume' => l10n.recurringResumedMsg,
        _ => l10n.recurringStoppedMsg,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final e = widget.expense;
    final me = SupabaseConfig.client.auth.currentUser?.id ?? '';
    final headingColor = dark ? AppColors.primaryTint : AppColors.primaryDark;
    final amAdmin = ref
            .watch(groupMembersProvider(widget.group.id))
            .valueOrNull
            ?.any((m) => m['user_id'] == me && m['role'] == 'admin') ??
        false;
    final canChange =
        me == (e.createdBy ?? e.paidBy) || me == e.paidBy || amAdmin;

    final every = switch (e.recurEvery) {
      'daily' => l10n.daily,
      'weekly' => l10n.weekly,
      _ => l10n.monthly,
    };
    final when = e.recurPaused
        ? l10n.recurPausedLabel
        : e.nextRecurAt != null
            ? l10n.nextOn(DateFormat.yMMMd(l10n.localeName).format(e.nextRecurAt!))
            : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? AppColors.primaryDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryTint, width: 0.5),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => showExpenseDetailSheet(context, e, widget.group),
            leading: Icon(
              e.recurPaused ? Icons.pause_circle_outline_rounded : Icons.repeat_rounded,
              color: e.recurPaused ? AppColors.accentDark : AppColors.primary,
            ),
            title: Text(e.title,
                style: TextStyle(
                    fontWeight: FontWeight.w500, color: headingColor)),
            subtitle: Text('$every · $when',
                style: TextStyle(
                    color: e.recurPaused
                        ? AppColors.accentDark
                        : (dark ? AppColors.primaryTint : AppColors.primaryDark))),
            trailing: Text(formatMoney(e.amount, e.currency),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
          if (canChange)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              _act(e.recurPaused ? 'resume' : 'pause'),
                          icon: Icon(e.recurPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded),
                          label: Text(e.recurPaused
                              ? l10n.resumeRepeating
                              : l10n.pauseRepeating),
                        ),
                        TextButton.icon(
                          onPressed: () => _act('stop'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger),
                          icon: const Icon(Icons.stop_rounded),
                          label: Text(l10n.stopRepeating),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}
