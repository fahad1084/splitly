import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase/supabase_config.dart';
import '../models/expense_model.dart';
import '../../balances/controllers/balances_controller.dart';
import 'package:splitly/core/utils/app_logger.dart';

// ── Expenses per group ────────────────────────────────────────────────────────
// autoDispose: loaded only while a screen of this group is open, and the
// group's realtime channel closes when the last one is left.
final expensesProvider = AsyncNotifierProvider.autoDispose
    .family<ExpensesController, List<ExpenseModel>, String>(
  ExpensesController.new,
);

class ExpensesController
    extends AutoDisposeFamilyAsyncNotifier<List<ExpenseModel>, String> {
  String get _groupId => arg;
  RealtimeChannel? _channel;
  Timer? _refreshDebounce;
  bool _disposed = false;

  @override
  Future<List<ExpenseModel>> build(String arg) async {
    final expenses = await _fetchExpenses();
    _subscribeToRealtime();
    ref.onDispose(() {
      _disposed = true;
      _refreshDebounce?.cancel();
      _channel?.unsubscribe();
    });
    return expenses;
  }

  // ── Live updates for the open group ────────────────────────────────────────
  // Someone else adds/deletes an expense or records/confirms a payment →
  // reload this group's expenses, balances and payments once (debounced, so
  // a burst of changes is one reload).
  void _subscribeToRealtime() {
    final groupFilter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'group_id',
      value: _groupId,
    );
    _channel = SupabaseConfig.client
        .channel('group-live:$_groupId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'expenses',
          filter: groupFilter,
          callback: (payload) {
            // Already in the list → our own save, which reloaded already
            final id = payload.newRecord['id'];
            if (state.value?.any((e) => e.id == id) ?? false) return;
            _scheduleRefresh();
          },
        )
        // Someone edited an expense of this group
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'expenses',
          filter: groupFilter,
          callback: (_) => _scheduleRefresh(),
        )
        // DELETE events can't be filtered and carry only the id: react only
        // when it is one of this group's expenses that we still show.
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'expenses',
          callback: (payload) {
            final id = payload.oldRecord['id'];
            if (state.value?.any((e) => e.id == id) ?? false) {
              _scheduleRefresh();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'settlements',
          filter: groupFilter,
          callback: (_) => _scheduleRefresh(),
        )
        .subscribe();
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 800), () async {
      if (_disposed) return;
      ref.invalidate(myDebtsProvider);
      ref.invalidate(settlementsProvider(_groupId));
      try {
        final fresh = await _fetchExpenses();
        if (!_disposed) state = AsyncValue.data(fresh);
      } catch (_) {
        // keep showing the current list; pull-to-refresh still works
      }
    });
  }

  Future<List<ExpenseModel>> _fetchExpenses() async {
    try {
      final List<dynamic> rows = await SupabaseConfig.client
          .from('expenses')
          .select('*, expense_splits(*)')
          .eq('group_id', _groupId)
          // Newest spending day first; same day → newest saved first
          .order('expense_date', ascending: false)
          .order('created_at', ascending: false);

      if (rows.isEmpty) return [];

      // ✅ Combine payer IDs + split user IDs into ONE set — avoids fetching
      // the same profile twice and cuts 2 separate DB round trips down to 1
      final allUserIds = <String>{};
      for (final r in rows) {
        allUserIds.add(r['paid_by'] as String);
        for (final s in (r['expense_splits'] as List? ?? [])) {
          allUserIds.add(s['user_id'] as String);
        }
      }

      final List<dynamic> profiles = await SupabaseConfig.client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', allUserIds.toList());

      final nameMap = <String, String>{
        for (final p in profiles) p['id'] as String: p['full_name'] as String,
      };

      return rows.map((r) {
        final splits = (r['expense_splits'] as List? ?? []).map((s) {
          return {
            ...Map<String, dynamic>.from(s),
            'user_name': nameMap[s['user_id']] ?? 'Unknown',
          };
        }).toList();

        return ExpenseModel.fromMap({
          ...Map<String, dynamic>.from(r),
          'paid_by_name': nameMap[r['paid_by']] ?? 'Someone',
          'expense_splits': splits,
        });
      }).toList();
    } catch (e) {
      logDebug('=== FETCH EXPENSES ERROR: $e ===');
      rethrow;
    }
  }

  // ── Add expense ─────────────────────────────────────────────────────────────
  Future<String?> addExpense({
    required String title,
    required double amount,
    required String category,
    required String paidBy,
    required String splitType,
    required List<Map<String, dynamic>> members,
    required String currency,
    required DateTime expenseDate,
    String? notes,
    bool isRecurring = false,
    String? recurEvery, // 'daily' | 'weekly' | 'monthly'
  }) async {
    try {
      final splits = calculateSplits(
        amount: amount,
        splitType: splitType,
        members: members,
      );

      // ONE call: the expense and all its splits are saved in a single
      // database transaction (all or nothing). The server checks that
      // everyone is a group member and that the splits add up exactly,
      // and works out the next recurring date. Currency comes from the group.
      await SupabaseConfig.client.rpc('add_expense', params: {
        'p_group_id': _groupId,
        'p_paid_by': paidBy,
        'p_title': title.trim(),
        'p_amount': amount,
        'p_splits': splits,
        'p_category': category,
        'p_split_type': splitType,
        'p_notes': notes?.trim(),
        'p_is_recurring': isRecurring,
        'p_recur_every': isRecurring ? recurEvery : null,
        'p_expense_date': dateOnly(expenseDate),
      });

      ref.invalidate(myDebtsProvider); // balances come from the database
      state = AsyncValue.data(await _fetchExpenses());
      return null;
    } on PostgrestException catch (e) {
      logDebug('=== ADD EXPENSE ERROR: ${e.message} ===');
      return expenseErrorCode(e.message);
    } catch (e) {
      logDebug('=== ADD EXPENSE ERROR: $e ===');
      return 'UNKNOWN';
    }
  }

  // ── Edit expense ────────────────────────────────────────────────────────────
  // Payer or group admin. Same split rules as adding; the payer can't change.
  // Returns null on success, or an error code (see expenseErrorCode).
  Future<String?> editExpense({
    required String expenseId,
    required String title,
    required double amount,
    required String category,
    required String splitType,
    required List<Map<String, dynamic>> members,
    required DateTime expenseDate,
    String? notes,
  }) async {
    try {
      final splits = calculateSplits(
        amount: amount,
        splitType: splitType,
        members: members,
      );

      // ONE call: the expense and its new splits change together
      await SupabaseConfig.client.rpc('edit_expense', params: {
        'p_expense_id': expenseId,
        'p_title': title.trim(),
        'p_amount': amount,
        'p_splits': splits,
        'p_category': category,
        'p_split_type': splitType,
        'p_notes': notes?.trim(),
        'p_expense_date': dateOnly(expenseDate),
      });

      ref.invalidate(myDebtsProvider);
      state = AsyncValue.data(await _fetchExpenses());
      return null;
    } on PostgrestException catch (e) {
      logDebug('=== EDIT EXPENSE ERROR: ${e.message} ===');
      return expenseErrorCode(e.message);
    } catch (e) {
      logDebug('=== EDIT EXPENSE ERROR: $e ===');
      return 'UNKNOWN';
    }
  }

  // ── Pause / resume / stop a recurring expense ───────────────────────────────
  // action: 'pause' | 'resume' | 'stop'. Creator, payer or group admin.
  Future<String?> setRecurringStatus(String expenseId, String action) async {
    try {
      await SupabaseConfig.client.rpc('set_recurring_status',
          params: {'p_expense_id': expenseId, 'p_action': action});
      state = AsyncValue.data(await _fetchExpenses());
      return null;
    } on PostgrestException catch (e) {
      logDebug('=== RECURRING STATUS ERROR: ${e.message} ===');
      return expenseErrorCode(e.message);
    } catch (e) {
      logDebug('=== RECURRING STATUS ERROR: $e ===');
      return 'UNKNOWN';
    }
  }

  // ── Delete expense ──────────────────────────────────────────────────────────
  // Returns null on success, or an error code (see expenseErrorCode).
  Future<String?> deleteExpense(String expenseId) async {
    try {
      // One call — the splits are deleted together with the expense
      await SupabaseConfig.client
          .rpc('delete_expense', params: {'p_expense_id': expenseId});
      ref.invalidate(myDebtsProvider);
      // Just drop it from the list — no need to download the rest again
      state = AsyncValue.data(
          (state.value ?? []).where((e) => e.id != expenseId).toList());
      return null;
    } catch (e) {
      logDebug('=== DELETE EXPENSE ERROR: $e ===');
      // Re-sync so a swiped-away expense comes back if the delete failed
      try {
        state = AsyncValue.data(await _fetchExpenses());
      } catch (_) {}
      return e is PostgrestException ? expenseErrorCode(e.message) : 'UNKNOWN';
    }
  }

  // Keeps showing the current list while loading, and if loading fails
  Future<void> refresh() async {
    state = const AsyncValue<List<ExpenseModel>>.loading().copyWithPrevious(state);
    ref.invalidate(myDebtsProvider); // pull-to-refresh reloads balances too
    try {
      state = AsyncValue.data(await _fetchExpenses());
    } catch (e, st) {
      state = AsyncValue<List<ExpenseModel>>.error(e, st).copyWithPrevious(state);
    }
  }

}

// ── Money helpers ─────────────────────────────────────────────────────────────
// Work in whole paisa (1/100 of the currency unit) so nothing is lost to
// floating-point rounding.
int toPaisa(double amount) => (amount * 100).round();
double fromPaisa(int paisa) => paisa / 100;

// 'yyyy-MM-dd' for a date column (the phone's own calendar day)
String dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// ── Split calculation ─────────────────────────────────────────────────────────
// Returns [{user_id, amount_owed}] for the members marked 'included'.
// Equal and percentage splits always add up EXACTLY to the amount: shares
// are rounded down to the paisa and the leftover paisa go one each to the
// first members. Example: 100 split 3 ways → 33.34, 33.33, 33.33.
List<Map<String, dynamic>> calculateSplits({
  required double amount,
  required String splitType,
  required List<Map<String, dynamic>> members,
}) {
  final included =
  members.where((m) => m['included'] as bool? ?? true).toList();
  if (included.isEmpty) return [];

  final totalPaisa = toPaisa(amount);
  final List<int> shares;

  switch (splitType) {
    case 'equal':
      final base = totalPaisa ~/ included.length;
      shares = List.filled(included.length, base);
      break;

    case 'custom':
      // The user typed each amount; the form checks they add up exactly
      return included
          .map((m) => {
        'user_id': m['user_id'] as String,
        'amount_owed': fromPaisa(
            toPaisa((m['custom_amount'] as num?)?.toDouble() ?? 0.0)),
      })
          .toList();

    case 'percentage':
      // Percentages as whole hundredths (33.33% → 3333). Each share is the
      // person's part of the total by their weight, rounded down; so
      // 33.33/33.33/33.33 (= 99.99%) still splits the WHOLE amount.
      final weights = included
          .map((m) => toPaisa((m['percentage'] as num?)?.toDouble() ?? 0.0))
          .toList();
      final totalWeight = weights.fold<int>(0, (a, b) => a + b);
      if (totalWeight <= 0) return [];
      shares = weights.map((w) => totalPaisa * w ~/ totalWeight).toList();
      break;

    default:
      return [];
  }

  // Hand out the leftover paisa, one each, starting with the first member
  var leftover = totalPaisa - shares.fold<int>(0, (a, b) => a + b);
  for (var i = 0; leftover > 0 && shares.isNotEmpty; i = (i + 1) % shares.length) {
    shares[i]++;
    leftover--;
  }

  return [
    for (var i = 0; i < included.length; i++)
      {
        'user_id': included[i]['user_id'] as String,
        'amount_owed': fromPaisa(shares[i]),
      },
  ];
}

// ── Do the percentages add up to 100%? ────────────────────────────────────────
// Each person types a percentage with up to 2 decimals, so 3 people can only
// get to 33.33 × 3 = 99.99%. Accept a total within 0.01% per person of 100%;
// calculateSplits() then shares out the whole amount anyway.
bool percentagesAddUp(List<double> percentages) {
  if (percentages.isEmpty) return false;
  final totalHundredths = percentages.fold<int>(0, (sum, p) => sum + toPaisa(p));
  return (totalHundredths - 10000).abs() <= percentages.length;
}

// ── Server error → code the UI can translate ─────────────────────────────────
// add_expense / edit_expense / delete_expense raise these codes as the
// error message (see supabase/migrations/20261027130000_transactions.sql
// and 20261030000100_edit_expense.sql).
const _expenseErrorCodes = {
  'NOT_A_MEMBER', 'INVALID_TITLE', 'INVALID_AMOUNT', 'PAYER_NOT_MEMBER',
  'INVALID_SPLIT_TYPE', 'INVALID_RECURRENCE', 'NO_MEMBERS', 'DUPLICATE_SPLIT',
  'INVALID_SPLIT_AMOUNT', 'SPLIT_USER_NOT_MEMBER', 'SPLITS_DONT_ADD_UP',
  'EXPENSE_NOT_FOUND', 'NOT_ALLOWED', 'INVALID_DATE', 'NOT_RECURRING',
};

String expenseErrorCode(String message) =>
    _expenseErrorCodes.contains(message) ? message : 'UNKNOWN';

