// Unit tests for buildGroupSummary(): it turns the debts the DATABASE
// calculated (group_debts / get_my_debts) into what the screens show.
// The balance math itself (splits − confirmed settlements, the Ali/Bilal
// example, partial payments, pending, cancel) is tested where it lives:
// supabase/tests/money_tests.sql.

import 'package:flutter_test/flutter_test.dart';
import 'package:splitly/features/balances/controllers/balances_controller.dart';
import 'package:splitly/features/balances/models/balance_model.dart';

const ali = 'ali', bilal = 'bilal', chand = 'chand';

DebtRow _row(String debtor, String creditor, double amount,
    {String group = 'g1', double pending = 0}) =>
    DebtRow(
      groupId: group,
      debtorId: debtor,
      debtorName: debtor,
      creditorId: creditor,
      creditorName: creditor,
      amount: amount,
      pendingAmount: pending,
    );

GroupBalanceSummary _summary(List<DebtRow> rows, {String me = ali}) =>
    buildGroupSummary(
      groupId: 'g1',
      groupName: 'Flat',
      currency: 'PKR',
      totalSpentPaisa: 32000,
      rows: rows,
      currentUserId: me,
    );

void main() {
  test('Ali/Bilal after Ali paid 40 and Bilal confirmed: no debts → all zero', () {
    // The database returns NO row for a pair that is even
    final s = _summary([]);
    expect(s.debts, isEmpty);
    expect(s.youOwe, 0);
    expect(s.youAreOwed, 0);
    expect(s.totalSpent, 320.0);
  });

  test('Ali owes Bilal 40 → Ali sees "you owe 40"', () {
    final s = _summary([_row(ali, bilal, 40)]);
    expect(s.youOwe, 40.0);
    expect(s.youAreOwed, 0);
    expect(s.debts.single.fromUserId, ali);
    expect(s.debts.single.currency, 'PKR');
  });

  test('the same debt seen by Bilal → "you are owed 40"', () {
    final s = _summary([_row(ali, bilal, 40)], me: bilal);
    expect(s.youAreOwed, 40.0);
    expect(s.youOwe, 0);
  });

  test('owed 50 by Chand, owe 20 to Bilal → net: you are owed 30', () {
    final s = _summary([_row(chand, ali, 50), _row(ali, bilal, 20)]);
    expect(s.youAreOwed, 30.0);
    expect(s.youOwe, 0);
    expect(s.debts, hasLength(2));
  });

  test('paisa are added exactly (0.10 + 0.20 = 0.30, not 0.30000000000000004)', () {
    final s = _summary([_row(chand, ali, 0.10), _row(bilal, ali, 0.20)]);
    expect(s.youAreOwed, 0.30);
  });

  test('a pending payment is shown but does NOT lower the debt', () {
    final s = _summary([_row(ali, bilal, 100, pending: 60)]);
    expect(s.youOwe, 100.0);
    expect(s.debts.single.pendingAmount, 60.0);
  });

  test('debts from other groups are ignored', () {
    final s = _summary([_row(ali, bilal, 40, group: 'other')]);
    expect(s.debts, isEmpty);
    expect(s.youOwe, 0);
  });
}
