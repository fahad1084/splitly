import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../groups/controllers/groups_controller.dart';
import '../../groups/models/group_model.dart';
import 'add_expense_sheet.dart';
import '../controllers/expenses_controller.dart';
import '../models/expense_model.dart';
import 'expense_tile.dart';
import '../../../core/utils/string_utils.dart';
import '../../../core/utils/money_format.dart';

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

void showExpenseDetailSheet(
    BuildContext context, ExpenseModel expense, GroupModel group) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _ExpenseDetailSheet(expense: expense, group: group),
  );
}

class _ExpenseDetailSheet extends ConsumerWidget {
  final ExpenseModel expense;
  final GroupModel group;
  const _ExpenseDetailSheet(
      {required this.expense, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final sheetBg = dark ? const Color(0xFF042F2E) : Colors.white;
    final headingColor =
    dark ? AppColors.primaryTint : AppColors.primaryDark;
    final cardBg =
    dark ? AppColors.primaryDark : AppColors.primaryTint;
    final currentUserId =
        ref.watch(currentUserProvider)?.id ?? '';
    final iPaid = expense.paidBy == currentUserId;
    // The payer or a group admin can edit
    final amAdmin = ref.watch(groupMembersProvider(group.id)).valueOrNull
            ?.any((m) => m['user_id'] == currentUserId && m['role'] == 'admin') ??
        false;

    final categoryIcon =
        _categoryIconMap[expense.category] ?? Icons.category_rounded;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Header ────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(categoryIcon,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.title,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: headingColor,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 3),
                    Text(
                      iPaid
                          ? l10n.youPaid
                          : l10n.userPaid(expense.paidByName),
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedText(context)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(expense.amount, expense.currency),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: headingColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    expense.category,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText(context)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Split type badge ───────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.splitLabel(expense.splitType),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDate(expense.expenseDate),
                style: TextStyle(
                    fontSize: 12, color: AppColors.mutedText(context)),
              ),
              if (expense.editedAt != null) ...[
                const SizedBox(width: 8),
                Text('· ${l10n.editedLabel}',
                    style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.mutedText(context))),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // ── Notes ─────────────────────────────────────────────────
          if (expense.notes != null && expense.notes!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(expense.notes!,
                        style: TextStyle(
                            fontSize: 13,
                            color: dark
                                ? AppColors.primaryTint
                                : AppColors.primaryDark,
                            height: 1.4)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Splits breakdown ───────────────────────────────────────
          Text(l10n.splitBreakdown,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: headingColor)),

          const SizedBox(height: 10),

          ...expense.splits.map((split) {
            final isMe = split.userId == currentUserId;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:
                    AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      getInitial(split.userName),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isMe ? l10n.youWord : split.userName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: headingColor,
                      ),
                    ),
                  ),
                  // Settled badge
                  if (split.isSettled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                        AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(l10n.settled,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.successText(context),
                              fontWeight: FontWeight.w500)),
                    )
                  else
                    Text(
                      formatMoney(split.amountOwed, expense.currency),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isMe && !iPaid
                            ? AppColors.dangerText(context)
                            : AppColors.mutedText(context),
                      ),
                    ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),

          // ── Edit button (payer or group admin) ────────────────────
          if (iPaid || amAdmin) ...[
            SplitlyButton(
              label: l10n.editExpense,
              icon: Icons.edit_rounded,
              onPressed: () {
                final nav = Navigator.of(context);
                nav.pop();
                showAddExpenseSheet(nav.context, group, expense: expense);
              },
            ),
            const SizedBox(height: 10),
          ],

          // ── Delete button (only if you paid) ──────────────────────
          if (iPaid)
            SplitlyButton(
              label: l10n.deleteExpense,
              isOutline: true,
              icon: Icons.delete_outline_rounded,
              onPressed: () async {
                // Same dialog as swipe-to-delete, incl. the payments warning
                final confirm =
                await confirmDeleteExpense(context, ref, expense);
                if (confirm && context.mounted) {
                  final error = await ref
                      .read(expensesProvider(group.id).notifier)
                      .deleteExpense(expense.id);
                  if (!context.mounted) return;
                  if (error != null) {
                    showErrorSnack(context, l10n.somethingWentWrong);
                  } else {
                    Navigator.pop(context);
                  }
                }
              },
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month]} ${d.day}, ${d.year}';
  }
}