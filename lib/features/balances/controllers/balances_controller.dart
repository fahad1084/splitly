import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../expenses/controllers/expenses_controller.dart';
import '../../balances/models/balance_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The balance math lives in the DATABASE (group_debts() in
// supabase/migrations/20261027140000_money_ledger.sql): what people owe from
// expense splits, minus CONFIRMED settlements, netted per pair. The app,
// leave_group() and the reminder Edge Function all use that one function.
// This file only loads its result and arranges it for the screens.
// ─────────────────────────────────────────────────────────────────────────────

// ── All debts in all my groups (ONE database call + one for names) ────────────
final myDebtsProvider = FutureProvider<List<DebtRow>>((ref) async {
  final db = SupabaseConfig.client;
  if (db.auth.currentUser == null) return [];

  final List<dynamic> rows = await db.rpc('get_my_debts');
  if (rows.isEmpty) return [];

  final ids = <String>{
    for (final r in rows) ...[r['debtor_id'] as String, r['creditor_id'] as String],
  };
  final List<dynamic> profiles = await db
      .from('profiles')
      .select('id, full_name')
      .inFilter('id', ids.toList());
  final names = <String, String>{
    for (final p in profiles)
      p['id'] as String: p['full_name'] as String? ?? 'Unknown',
  };

  return rows.map((r) {
    final debtor = r['debtor_id'] as String;
    final creditor = r['creditor_id'] as String;
    return DebtRow(
      groupId: r['group_id'] as String,
      debtorId: debtor,
      debtorName: names[debtor] ?? 'Unknown',
      creditorId: creditor,
      creditorName: names[creditor] ?? 'Unknown',
      amount: (r['amount'] as num).toDouble(),
      pendingAmount: (r['pending_amount'] as num?)?.toDouble() ?? 0,
    );
  }).toList();
});

// ── Single group balance ──────────────────────────────────────────────────────
// Keyed by a Dart record, which compares by VALUE — so the same group always
// gets the same provider (a Map key created a new provider on every build).
typedef GroupBalanceKey = ({String id, String name, String currency});

final groupBalanceSummaryProvider =
Provider.family<GroupBalanceSummary, GroupBalanceKey>((ref, group) {
  final expenses = ref.watch(expensesProvider(group.id)).value ?? [];
  final rows = ref.watch(myDebtsProvider).value ?? [];
  final currentUserId = SupabaseConfig.client.auth.currentUser?.id ?? '';

  return buildGroupSummary(
    groupId: group.id,
    groupName: group.name,
    currency: group.currency,
    totalSpentPaisa:
    expenses.fold<int>(0, (sum, e) => sum + toPaisa(e.amount)),
    rows: rows,
    currentUserId: currentUserId,
  );
});

// ── Arrange the database's debts for one group (pure, unit-tested) ────────────
// youAreOwed / youOwe show the current user's NET position in the group
// (only one of them is non-zero), worked out in whole paisa.
GroupBalanceSummary buildGroupSummary({
  required String groupId,
  required String groupName,
  required String currency,
  required int totalSpentPaisa,
  required List<DebtRow> rows,
  required String currentUserId,
}) {
  final debts = <DebtModel>[];
  var netPaisa = 0; // positive = others owe me

  for (final r in rows.where((r) => r.groupId == groupId)) {
    if (r.creditorId == currentUserId) netPaisa += toPaisa(r.amount);
    if (r.debtorId == currentUserId) netPaisa -= toPaisa(r.amount);
    debts.add(DebtModel(
      fromUserId: r.debtorId,
      fromUserName: r.debtorName,
      toUserId: r.creditorId,
      toUserName: r.creditorName,
      amount: r.amount,
      currency: currency,
      groupId: groupId,
      groupName: groupName,
      pendingAmount: r.pendingAmount,
    ));
  }

  return GroupBalanceSummary(
    groupId: groupId,
    groupName: groupName,
    currency: currency,
    totalSpent: fromPaisa(totalSpentPaisa),
    youAreOwed: netPaisa > 0 ? fromPaisa(netPaisa) : 0,
    youOwe: netPaisa < 0 ? fromPaisa(-netPaisa) : 0,
    debts: debts,
  );
}

// ── Payment history of one group ──────────────────────────────────────────────
// 'migrated' rows are hidden: they only carry over what was already settled
// before payments were tracked (old payments still show, as 'legacy').
final settlementsProvider =
FutureProvider.family<List<SettlementModel>, String>((ref, groupId) async {
  final db = SupabaseConfig.client;
  final List<dynamic> rows = await db
      .from('settlements')
      .select('id, group_id, paid_by, paid_to, amount, currency, status, created_at')
      .eq('group_id', groupId)
      .neq('kind', 'migrated')
      .order('created_at', ascending: false);
  if (rows.isEmpty) return [];

  final ids = <String>{
    for (final r in rows) ...[r['paid_by'] as String, r['paid_to'] as String],
  };
  final List<dynamic> profiles = await db
      .from('profiles')
      .select('id, full_name')
      .inFilter('id', ids.toList());
  final names = <String, String>{
    for (final p in profiles)
      p['id'] as String: p['full_name'] as String? ?? 'Unknown',
  };

  return rows
      .map((r) => SettlementModel.fromMap(Map<String, dynamic>.from(r), names))
      .toList();
});

// ── Settle Up Controller ──────────────────────────────────────────────────────
// Each action is ONE database call; the database checks who may do it and
// that the amount is never more than is still owed.
final settleUpProvider =
StateNotifierProvider<SettleUpController, AsyncValue<void>>(
      (ref) => SettleUpController(ref),
);

class SettleUpController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  SettleUpController(this._ref) : super(const AsyncValue.data(null));

  // The debtor recording "I paid" → pending until the receiver confirms.
  // The receiver recording "I got paid" → confirmed at once.
  Future<String?> recordSettlement({
    required String groupId,
    required String paidBy,   // person paying
    required String paidTo,   // person receiving
    required double amount,
  }) {
    return _run(groupId, () => SupabaseConfig.client.rpc('record_settlement', params: {
      'p_group_id': groupId,
      'p_paid_by': paidBy,
      'p_paid_to': paidTo,
      'p_amount': fromPaisa(toPaisa(amount)),
    }));
  }

  Future<String?> confirmSettlement(String groupId, String settlementId) {
    return _run(groupId, () => SupabaseConfig.client.rpc('confirm_settlement',
        params: {'p_settlement_id': settlementId}));
  }

  Future<String?> cancelSettlement(String groupId, String settlementId) {
    return _run(groupId, () => SupabaseConfig.client.rpc('cancel_settlement',
        params: {'p_settlement_id': settlementId}));
  }

  // Returns null on success, or an error code (see settleErrorCode).
  Future<String?> _run(String groupId, Future<dynamic> Function() call) async {
    state = const AsyncValue.loading();
    try {
      await call();
      _ref.invalidate(myDebtsProvider);
      _ref.invalidate(settlementsProvider(groupId));
      state = const AsyncValue.data(null);
      return null;
    } on PostgrestException catch (e) {
      print('=== SETTLE UP ERROR: ${e.message} ===');
      state = const AsyncValue.data(null);
      return settleErrorCode(e.message);
    } catch (e) {
      print('=== SETTLE UP ERROR: $e ===');
      state = const AsyncValue.data(null);
      return 'UNKNOWN';
    }
  }
}

// ── Server error → code the UI can translate ─────────────────────────────────
const _settleErrorCodes = {
  'NOT_A_MEMBER', 'NOT_ALLOWED', 'INVALID_AMOUNT', 'NO_DEBT',
  'AMOUNT_TOO_HIGH', 'NOT_FOUND', 'NOT_PENDING', 'HAS_UNSETTLED_DEBTS',
};

String settleErrorCode(String message) =>
    _settleErrorCodes.contains(message) ? message : 'UNKNOWN';
