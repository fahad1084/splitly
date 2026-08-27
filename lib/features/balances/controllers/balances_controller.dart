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

  // Pairwise direct debts — every debt shown is a DIRECT relationship
  // between two people (never rerouted through an uninvolved third
  // person just to minimize transaction count, unlike a global
  // "simplify debts" algorithm — this keeps the numbers intuitive and
  // traceable to real expenses between those exact two people).
  final debts = _pairwiseDebts(
    expenses: expenses,
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

// ── Pairwise direct debts (no global rerouting) ───────────────────────────────
List<DebtModel> _pairwiseDebts({
  required List expenses,
  required Map<String, String> nameMap,
  required String groupId,
  required String groupName,
  required String currency,
}) {
  // ledger[debtor][creditor] = total amount debtor owes creditor,
  // accumulated across every expense between exactly these two people.
  final ledger = <String, Map<String, double>>{};

  void addOwed(String debtor, String creditor, double amount) {
    ledger.putIfAbsent(debtor, () => {});
    ledger[debtor]![creditor] = (ledger[debtor]![creditor] ?? 0) + amount;
  }

  for (final expense in expenses) {
    final payer = expense.paidBy;
    for (final split in expense.splits) {
      if (split.isSettled) continue;
      if (split.userId == payer) continue; // payer doesn't owe themselves
      addOwed(split.userId, payer, split.amountOwed);
    }
  }

  final debts = <DebtModel>[];
  final seenPairs = <String>{};

  for (final a in ledger.keys) {
    for (final b in ledger[a]!.keys) {
      final pairKey = ([a, b]..sort()).join('|');
      if (seenPairs.contains(pairKey)) continue;
      seenPairs.add(pairKey);

      final aOwesB = ledger[a]?[b] ?? 0;
      final bOwesA = ledger[b]?[a] ?? 0;
      final net = aOwesB - bOwesA;

      if (net.abs() < 0.01) continue; // fully settled between these two

      final debtorId = net > 0 ? a : b;
      final creditorId = net > 0 ? b : a;
      final amount = double.parse(net.abs().toStringAsFixed(2));

      debts.add(DebtModel(
        fromUserId: debtorId,
        fromUserName: nameMap[debtorId] ?? 'Unknown',
        toUserId: creditorId,
        toUserName: nameMap[creditorId] ?? 'Unknown',
        amount: amount,
        currency: currency,
        groupId: groupId,
        groupName: groupName,
      ));
    }
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