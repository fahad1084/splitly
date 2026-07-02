import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../balances/controllers/balances_controller.dart';
import '../../expenses/controllers/expenses_controller.dart';
import '../../groups/models/group_model.dart';

void showShareSummarySheet(BuildContext context, GroupModel group) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShareSummarySheet(group: group),
  );
}

class _ShareSummarySheet extends ConsumerWidget {
  final GroupModel group;
  const _ShareSummarySheet({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = isDark(context);
    final sheetBg = dark ? const Color(0xFF042F2E) : Colors.white;
    final headingColor =
    dark ? AppColors.primaryTint : AppColors.primaryDark;
    final cardBg =
    dark ? AppColors.primaryDark : AppColors.primaryTint;

    final expenses =
        ref.watch(expensesProvider(group.id)).value ?? [];
    final summary = ref.watch(groupBalanceSummaryProvider({
      'groupId': group.id,
      'groupName': group.name,
      'currency': group.currency,
    }));

    final currentUserId =
        SupabaseConfig.client.auth.currentUser?.id ?? '';

    // Generate summary text
    final summaryText = _generateSummary(
      group: group,
      expenses: expenses,
      summary: summary,
      currentUserId: currentUserId,
    );

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
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

          // Title
          Text('Share Summary',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: headingColor,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text('Share ${group.name} expense summary',
              style:
              TextStyle(fontSize: 13, color: AppColors.primary)),

          const SizedBox(height: 20),

          // Preview card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.primaryLight.withOpacity(0.3),
                  width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.preview_rounded,
                        size: 14, color: AppColors.primaryLight),
                    const SizedBox(width: 6),
                    Text('Preview',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  summaryText,
                  style: TextStyle(
                    fontSize: 12,
                    color: dark
                        ? AppColors.primaryTint.withOpacity(0.8)
                        : AppColors.primaryDark.withOpacity(0.8),
                    height: 1.6,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 12,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Share buttons
          Row(
            children: [
              // WhatsApp
              Expanded(
                child: GestureDetector(
                  onTap: () => _shareToWhatsApp(summaryText),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366), // WhatsApp green
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.chat_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('WhatsApp',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Copy
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: summaryText));
                    showSuccessSnack(context, 'Summary copied!');
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.primary, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.copy_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text('Copy',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // More options
              Expanded(
                child: GestureDetector(
                  onTap: () => _shareGeneral(summaryText),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.share_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Share',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Generate WhatsApp-ready summary text ──────────────────────────────────
  String _generateSummary({
    required GroupModel group,
    required List expenses,
    required summary,
    required String currentUserId,
  }) {
    final now = DateTime.now();
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr =
        '${months[now.month]} ${now.day}, ${now.year}';

    final buffer = StringBuffer();

    // Header
    buffer.writeln('💸 *Splitly — ${group.name}*');
    buffer.writeln('📅 $dateStr');
    buffer.writeln('─────────────────');

    // Balance summary
    buffer.writeln('💰 *Balance Summary*');
    buffer.writeln(
        '• Total spent: ${group.currency} ${summary.totalSpent.toStringAsFixed(0)}');
    if (summary.youAreOwed > 0) {
      buffer.writeln(
          '• You are owed: ${group.currency} ${summary.youAreOwed.toStringAsFixed(0)}');
    }
    if (summary.youOwe > 0) {
      buffer.writeln(
          '• You owe: ${group.currency} ${summary.youOwe.toStringAsFixed(0)}');
    }

    // Who owes who
    if (summary.debts.isNotEmpty) {
      buffer.writeln('─────────────────');
      buffer.writeln('🤝 *Who Owes Who*');
      for (final debt in summary.debts) {
        buffer.writeln(
            '• ${debt.fromUserName} → ${debt.toUserName}: ${debt.currency} ${debt.amount.toStringAsFixed(0)}');
      }
    }

    // Recent expenses (last 5)
    if (expenses.isNotEmpty) {
      buffer.writeln('─────────────────');
      buffer.writeln('🧾 *Recent Expenses*');
      final recent = expenses.take(5).toList();
      for (final expense in recent) {
        buffer.writeln(
            '• ${expense.title} — ${expense.currency} ${expense.amount.toStringAsFixed(0)} (${expense.paidByName})');
      }
      if (expenses.length > 5) {
        buffer
            .writeln('  ...and ${expenses.length - 5} more');
      }
    }

    buffer.writeln('─────────────────');
    buffer.writeln('_Sent via Splitly — Your Circle. Your Hisaab._');

    return buffer.toString();
  }

  void _shareToWhatsApp(String text) {
    // share_plus will open WhatsApp if available on Android
    Share.share(text, subject: 'Splitly Expense Summary');
  }

  void _shareGeneral(String text) {
    Share.share(text, subject: 'Splitly Expense Summary');
  }
}