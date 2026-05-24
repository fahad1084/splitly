import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../groups/controllers/groups_controller.dart';
import '../../expenses/controllers/expenses_controller.dart';
import '../../balances/models/balance_model.dart';

// ── All group balances for current user ───────────────────────────────────────
final allBalancesProvider =
FutureProvider<List<GroupBalanceSummary>>((ref) async {
  final groups = ref.watch(groupsProvider).value ?? [];
  final currentUserId =
      SupabaseConfig.client.auth.currentUser?.id ?? '';

  final summaries = <GroupBalanceSummary>[];

  for (final group in groups) {
    final expenses =
        ref.watch(expensesProvider(group.id)).value ?? [];

    final summary = _calculateGroupBalance(
      groupId: group.id,
      groupName: group.name,
      currency: group.currency,
      expenses: expenses,
      currentUserId: currentUserId,
    );
    summaries.add(summary);
  }

  return summaries;
});

// ── Single group balance ──────────────────────────────────────────────────────
final groupBalanceSummaryProvider =
Provider.family<GroupBalanceSummary, Map<String, dynamic>>(
        (ref, args) {
      final groupId = args['groupId'] as String;
      final groupName = args['groupName'] as String;
      final currency = args['currency'] as String;
      final currentUserId =
          SupabaseConfig.client.auth.currentUser?.id ?? '';

      final expenses =
          ref.watch(expensesProvider(groupId)).value ?? [];

      return _calculateGroupBalance(
        groupId: groupId,
        groupName: groupName,
        currency: currency,
        expenses: expenses,
        currentUserId: currentUserId,
      );
    });

// ── Core balance calculation algorithm ───────────────────────────────────────
GroupBalanceSummary _calculateGroupBalance({
  required String groupId,
  required String groupName,
  required String currency,
  required List expenses,
  required String currentUserId,
}) {
  double totalSpent = 0;
  double youAreOwed = 0;
  double youOwe = 0;

  // net[userId] = positive means they are owed, negative means they owe
  final netMap = <String, double>{};
  final nameMap = <String, String>{};

  for (final expense in expenses) {
    totalSpent += expense.amount;
    nameMap[expense.paidBy] = expense.paidByName;

    for (final split in expense.splits) {
      if (split.isSettled) continue;
      nameMap[split.userId] = split.userName;

      if (expense.paidBy == split.userId) continue; // payer doesn't owe themselves

      // The payer is owed this split amount
      netMap[expense.paidBy] =
          (netMap[expense.paidBy] ?? 0) + split.amountOwed;

      // The split person owes this amount
      netMap[split.userId] =
          (netMap[split.userId] ?? 0) - split.amountOwed;
    }
  }

  // Calculate current user's totals
  for (final entry in netMap.entries) {
    if (entry.key == currentUserId) {
      if (entry.value > 0) {
        youAreOwed = entry.value;
      } else {
        youOwe = entry.value.abs();
      }
    }
  }

  // Simplify debts using greedy algorithm
  final debts = _simplifyDebts(
    netMap: netMap,
    nameMap: nameMap,
    groupId: groupId,
    groupName: groupName,
    currency: currency,
  );

  return GroupBalanceSummary(
    groupId: groupId,
    groupName: groupName,
    currency: currency,
    totalSpent: totalSpent,
    youAreOwed: youAreOwed,
    youOwe: youOwe,
    debts: debts,
  );
}

// ── Debt simplification (minimizes number of transactions) ───────────────────
List<DebtModel> _simplifyDebts({
  required Map<String, double> netMap,
  required Map<String, String> nameMap,
  required String groupId,
  required String groupName,
  required String currency,
}) {
  final debts = <DebtModel>[];
  final balances = Map<String, double>.from(netMap);

  while (true) {
    // Find max creditor (most owed to) and max debtor (owes most)
    String? maxCreditor;
    String? maxDebtor;
    double maxCredit = 0.01; // threshold to avoid tiny rounding amounts
    double maxDebt = 0.01;

    for (final entry in balances.entries) {
      if (entry.value > maxCredit) {
        maxCredit = entry.value;
        maxCreditor = entry.key;
      }
      if (entry.value < -maxDebt) {
        maxDebt = entry.value.abs();
        maxDebtor = entry.key;
      }
    }

    if (maxCreditor == null || maxDebtor == null) break;

    final amount = maxCredit < maxDebt ? maxCredit : maxDebt;
    final rounded = double.parse(amount.toStringAsFixed(2));

    debts.add(DebtModel(
      fromUserId: maxDebtor,
      fromUserName: nameMap[maxDebtor] ?? 'Unknown',
      toUserId: maxCreditor,
      toUserName: nameMap[maxCreditor] ?? 'Unknown',
      amount: rounded,
      currency: currency,
      groupId: groupId,
      groupName: groupName,
    ));

    balances[maxCreditor] = (balances[maxCreditor] ?? 0) - amount;
    balances[maxDebtor] = (balances[maxDebtor] ?? 0) + amount;
  }

  return debts;
}

// ── Settle Up Controller ──────────────────────────────────────────────────────
final settleUpProvider =
StateNotifierProvider<SettleUpController, AsyncValue<void>>(
      (ref) => SettleUpController(ref),
);

class SettleUpController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  SettleUpController(this._ref) : super(const AsyncValue.data(null));

  Future<String?> settleUp({
    required String groupId,
    required String paidBy,   // person paying
    required String paidTo,   // person receiving
    required double amount,
    required String currency,
  }) async {
    state = const AsyncValue.loading();
    try {
      final settlementId = const Uuid().v4();

      // 1 — Insert settlement record
      await SupabaseConfig.client.from('settlements').insert({
        'id': settlementId,
        'group_id': groupId,
        'paid_by': paidBy,
        'paid_to': paidTo,
        'amount': amount,
        'currency': currency,
      });

      // 2 — Mark relevant expense splits as settled
      // Get all unsettled splits where paidBy owes paidTo
      final List<dynamic> expenses = await SupabaseConfig.client
          .from('expenses')
          .select('id')
          .eq('group_id', groupId)
          .eq('paid_by', paidTo); // expenses paid by the creditor

      if (expenses.isNotEmpty) {
        final expenseIds =
        expenses.map((e) => e['id'] as String).toList();

        await SupabaseConfig.client
            .from('expense_splits')
            .update({'is_settled': true, 'settled_at': DateTime.now().toIso8601String()})
            .eq('user_id', paidBy)
            .eq('is_settled', false)
            .inFilter('expense_id', expenseIds);
      }

      // 3 — Refresh expenses
      _ref.invalidate(expensesProvider(groupId));

      state = const AsyncValue.data(null);
      return null;
    } catch (e) {
      print('=== SETTLE UP ERROR: $e ===');
      state = const AsyncValue.data(null);
      return 'Error: $e';
    }
  }
}