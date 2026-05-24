import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../config/supabase/supabase_config.dart';
import '../models/expense_model.dart';

// ── Expenses per group ────────────────────────────────────────────────────────
final expensesProvider =
AsyncNotifierProviderFamily<ExpensesController, List<ExpenseModel>, String>(
  ExpensesController.new,
);

class ExpensesController
    extends FamilyAsyncNotifier<List<ExpenseModel>, String> {
  String get _groupId => arg;

  @override
  Future<List<ExpenseModel>> build(String arg) async {
    return _fetchExpenses();
  }

  Future<List<ExpenseModel>> _fetchExpenses() async {
    try {
      final List<dynamic> rows = await SupabaseConfig.client
          .from('expenses')
          .select('*, expense_splits(*)')
          .eq('group_id', _groupId)
          .order('created_at', ascending: false);

      // Fetch payer names separately
      final payerIds =
      rows.map((r) => r['paid_by'] as String).toSet().toList();
      final List<dynamic> profiles = await SupabaseConfig.client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', payerIds);

      final nameMap = <String, String>{
        for (final p in profiles) p['id'] as String: p['full_name'] as String,
      };

      // Fetch split user names
      final allSplits = rows
          .expand((r) => (r['expense_splits'] as List? ?? []))
          .toList();
      final splitUserIds =
      allSplits.map((s) => s['user_id'] as String).toSet().toList();
      final List<dynamic> splitProfiles = splitUserIds.isEmpty
          ? []
          : await SupabaseConfig.client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', splitUserIds);
      final splitNameMap = <String, String>{
        for (final p in splitProfiles)
          p['id'] as String: p['full_name'] as String,
      };

      return rows.map((r) {
        final splits = (r['expense_splits'] as List? ?? []).map((s) {
          return {
            ...Map<String, dynamic>.from(s),
            'user_name': splitNameMap[s['user_id']] ?? 'Unknown',
          };
        }).toList();

        return ExpenseModel.fromMap({
          ...Map<String, dynamic>.from(r),
          'paid_by_name': nameMap[r['paid_by']] ?? 'Someone',
          'expense_splits': splits,
        });
      }).toList();
    } catch (e) {
      print('=== FETCH EXPENSES ERROR: $e ===');
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
    String? notes,
  }) async {
    try {
      final expenseId = const Uuid().v4();

      // Calculate splits based on type
      final splits = _calculateSplits(
        expenseId: expenseId,
        amount: amount,
        splitType: splitType,
        members: members,
      );

      // Insert expense
      await SupabaseConfig.client.from('expenses').insert({
        'id': expenseId,
        'group_id': _groupId,
        'paid_by': paidBy,
        'title': title.trim(),
        'amount': amount,
        'currency': currency,
        'category': category,
        'split_type': splitType,
        'notes': notes?.trim(),
      });

      // Insert splits
      await SupabaseConfig.client.from('expense_splits').insert(splits);

      state = AsyncValue.data(await _fetchExpenses());
      return null;
    } catch (e) {
      print('=== ADD EXPENSE ERROR: $e ===');
      return 'Error: $e';
    }
  }

  // ── Delete expense ──────────────────────────────────────────────────────────
  Future<void> deleteExpense(String expenseId) async {
    try {
      await SupabaseConfig.client
          .from('expense_splits')
          .delete()
          .eq('expense_id', expenseId);
      await SupabaseConfig.client
          .from('expenses')
          .delete()
          .eq('id', expenseId);
      state = AsyncValue.data(await _fetchExpenses());
    } catch (e) {
      print('=== DELETE EXPENSE ERROR: $e ===');
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _fetchExpenses());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ── Split calculation ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> _calculateSplits({
    required String expenseId,
    required double amount,
    required String splitType,
    required List<Map<String, dynamic>> members,
  }) {
    final activeMemberIds = members
        .where((m) => m['included'] as bool? ?? true)
        .map((m) => m['user_id'] as String)
        .toList();

    if (activeMemberIds.isEmpty) return [];

    switch (splitType) {
      case 'equal':
        final share = double.parse(
            (amount / activeMemberIds.length).toStringAsFixed(2));
        return activeMemberIds.map((uid) {
          return {
            'id': const Uuid().v4(),
            'expense_id': expenseId,
            'user_id': uid,
            'amount_owed': share,
            'is_settled': false,
          };
        }).toList();

      case 'custom':
        return members
            .where((m) => m['included'] as bool? ?? true)
            .map((m) {
          return {
            'id': const Uuid().v4(),
            'expense_id': expenseId,
            'user_id': m['user_id'] as String,
            'amount_owed':
            (m['custom_amount'] as num?)?.toDouble() ?? 0.0,
            'is_settled': false,
          };
        }).toList();

      case 'percentage':
        return members
            .where((m) => m['included'] as bool? ?? true)
            .map((m) {
          final pct = (m['percentage'] as num?)?.toDouble() ?? 0.0;
          return {
            'id': const Uuid().v4(),
            'expense_id': expenseId,
            'user_id': m['user_id'] as String,
            'amount_owed':
            double.parse((amount * pct / 100).toStringAsFixed(2)),
            'is_settled': false,
          };
        }).toList();

      default:
        return [];
    }
  }
}

// ── Balance calculation per group ─────────────────────────────────────────────
final groupBalancesProvider =
FutureProvider.family<Map<String, double>, String>((ref, groupId) async {
  final expensesAsync = ref.watch(expensesProvider(groupId));
  final expenses = expensesAsync.value ?? [];
  final currentUserId =
      SupabaseConfig.client.auth.currentUser?.id ?? '';

  // net balance: positive = owed to you, negative = you owe
  double netBalance = 0;
  for (final expense in expenses) {
    if (expense.paidBy == currentUserId) {
      // You paid — others owe you
      for (final split in expense.splits) {
        if (split.userId != currentUserId && !split.isSettled) {
          netBalance += split.amountOwed;
        }
      }
    } else {
      // Someone else paid — you owe your share
      for (final split in expense.splits) {
        if (split.userId == currentUserId && !split.isSettled) {
          netBalance -= split.amountOwed;
        }
      }
    }
  }

  return {'net': netBalance};
});