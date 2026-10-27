import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../balances/screens/settlement_history_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../expenses/controllers/expenses_controller.dart';
import '../../expenses/screens/expense_detail_sheet.dart';
import '../../expenses/screens/recurring_expenses_screen.dart';
import '../../groups/controllers/groups_controller.dart';
import '../../groups/models/group_model.dart';
import '../../groups/screens/group_detail_screen.dart';
import 'package:splitly/core/utils/app_logger.dart';

// ── Open what a notification is about ─────────────────────────────────────────
// Used for a tapped push (FCMService) and a tapped inbox item. Always opens
// the group first, so Back goes to the group, then:
//   message           → group chat
//   expense           → that expense's detail sheet
//   settlement        → payment history
//   recurring_skipped → recurring expenses
//   anything else     → the group (member joined, debt reminder)
// When the group (or expense) is gone, or the user left it, a short message
// says so instead.
Future<void> openNotificationTarget(
  NavigatorState nav,
  ProviderContainer container, {
  required String? type,
  required String? groupId,
  String? entityId,
}) async {
  if (groupId == null || groupId.isEmpty) return;
  final context = nav.context;
  final l10n = AppLocalizations.of(context)!;

  GroupModel? group;
  try {
    group = await container.read(groupDetailProvider(groupId).future);
  } catch (e) {
    logDebug('=== OPEN NOTIFICATION: group $groupId not available: $e ===');
  }
  if (!context.mounted) return; // the navigator's own context
  if (group == null || group.isArchived) {
    showErrorSnack(context, l10n.groupNoLongerAvailable);
    return;
  }
  final g = group;

  nav.push(MaterialPageRoute(builder: (_) => GroupDetailScreen(group: g)));

  switch (type) {
    case 'message':
      nav.push(MaterialPageRoute(builder: (_) => ChatScreen(group: g)));
      break;
    case 'settlement':
      nav.push(MaterialPageRoute(
          builder: (_) => SettlementHistoryScreen(group: g)));
      break;
    case 'recurring_skipped':
      nav.push(MaterialPageRoute(
          builder: (_) => RecurringExpensesScreen(group: g)));
      break;
    case 'expense':
      if (entityId == null || entityId.isEmpty) break;
      try {
        // The group screen keeps this list loaded (and live)
        final expenses = await container.read(expensesProvider(g.id).future);
        if (!nav.mounted) return;
        final matches = expenses.where((e) => e.id == entityId);
        if (matches.isEmpty) {
          showErrorSnack(nav.context, l10n.expenseNoLongerExists);
        } else {
          showExpenseDetailSheet(nav.context, matches.first, g);
        }
      } catch (e) {
        logDebug('=== OPEN NOTIFICATION: expenses not loaded: $e ===');
      }
      break;
  }
}
