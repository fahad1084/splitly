import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../models/expense_model.dart';
import '../../balances/controllers/balances_controller.dart';
import '../../../core/utils/string_utils.dart';
import '../../../core/utils/money_format.dart';

// Matches _categoryIcons in add_expense_sheet.dart
const _categoryIconMap = {
  'food':          Icons.restaurant_rounded,
  'ration':        Icons.shopping_cart_rounded,
  'utilities':     Icons.bolt_rounded,
  'transport':     Icons.directions_car_rounded,
  'rent':          Icons.home_rounded,
  'entertainment': Icons.sports_esports_rounded,
  'medicine':      Icons.medical_services_rounded,
  'travel':        Icons.flight_rounded,
  'other':         Icons.category_rounded,
};

// ── "Delete expense?" dialog (used by the tile and the detail sheet) ──────────
// Adds a warning when payments were already recorded after this expense
// between its people: deleting it changes balances they paid against.
Future<bool> confirmDeleteExpense(
    BuildContext context, WidgetRef ref, ExpenseModel expense) async {
  final l10n = AppLocalizations.of(context)!;
  var warn = false;
  try {
    final payments =
    await ref.read(settlementsProvider(expense.groupId).future);
    warn = hasPaymentsAfterExpense(expense, payments);
  } catch (_) {
    warn = false; // can't check (offline?) — the normal question still shows
  }
  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.deleteExpense),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.deleteExpenseConfirm(expense.title)),
          if (warn) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.accentDark, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.expenseHasPaymentsWarning,
                      style: TextStyle(
                          color: AppColors.warningText(context),
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class ExpenseTile extends ConsumerWidget {
  final ExpenseModel expense;
  final String currentUserId;
  final VoidCallback? onDelete;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.currentUserId,
    this.onDelete,
  });

  IconData get _categoryIcon =>
      _categoryIconMap[expense.category] ?? Icons.category_rounded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final iPaid = expense.paidBy == currentUserId;

    // Find current user's share
    final myShare = expense.splits
        .where((s) => s.userId == currentUserId)
        .fold(0.0, (sum, s) => sum + s.amountOwed);

    return Dismissible(
      key: Key(expense.id),
      direction: iPaid
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (_) => confirmDeleteExpense(context, ref, expense),
      onDismissed: (_) => onDelete?.call(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
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
            // ── Category icon ─────────────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: dark
                    ? AppColors.primary.withOpacity(0.2)
                    : AppColors.primaryTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _categoryIcon,
                color: AppColors.primary,
                size: 22,
              ),
            ),

            const SizedBox(width: 12),

            // ── Title + paid by ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          expense.title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: dark
                                ? AppColors.primaryTint
                                : AppColors.primaryDark,
                          ),
                        ),
                      ),
                      if (expense.isRecurring) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.repeat_rounded,
                            size: 13,
                            color: AppColors.primary.withOpacity(0.7)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (iPaid
                            ? l10n.youPaid
                            : l10n.userPaid(expense.paidByName)) +
                        (expense.editedAt != null
                            ? ' · ${l10n.editedLabel}'
                            : ''),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedText(context),
                    ),
                  ),
                ],
              ),
            ),

            // ── Amount + balance ──────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(expense.amount, expense.currency),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: dark
                        ? AppColors.primaryTint
                        : AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  iPaid
                      ? l10n.youLent
                      : l10n.youOweAmount(
                      formatMoney(myShare, expense.currency)),
                  style: TextStyle(
                    fontSize: 11,
                    color: iPaid
                        ? AppColors.successText(context)
                        : AppColors.dangerText(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}