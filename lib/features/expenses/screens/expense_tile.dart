import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../models/expense_model.dart';

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

class ExpenseTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Expense'),
            content: Text(
                'Delete "${expense.title}"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
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
                  Text(
                    expense.title,
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
                        ? 'You paid'
                        : '${expense.paidByName} paid',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryLight,
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
                  '${expense.currency} ${expense.amount.toStringAsFixed(0)}',
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
                      ? 'you lent'
                      : 'you owe ${expense.currency} ${myShare.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: iPaid
                        ? AppColors.success
                        : AppColors.danger,
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