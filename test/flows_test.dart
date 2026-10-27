// The main flows, from tapping in the UI to what is sent to the server:
// add expense, edit expense, settle up and confirm, join a group.
// Fakes replace Supabase (see fakes.dart), so no internet is needed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:splitly/core/widgets/shared_widgets.dart';
import 'package:splitly/features/balances/controllers/balances_controller.dart';
import 'package:splitly/features/balances/models/balance_model.dart';
import 'package:splitly/features/balances/screens/settle_up_sheet.dart';
import 'package:splitly/features/balances/screens/settlement_history_screen.dart';
import 'package:splitly/features/expenses/controllers/expenses_controller.dart';
import 'package:splitly/features/expenses/models/expense_model.dart';
import 'package:splitly/features/expenses/screens/add_expense_sheet.dart';
import 'package:splitly/features/expenses/screens/expense_detail_sheet.dart';
import 'package:splitly/features/groups/screens/join_group_screen.dart';

import 'fakes.dart';

Future<void> tapButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(SplitlyButton, label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> openIt(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('add expense: 100 split equally between Ali and Bilal',
      (tester) async {
    useTallScreen(tester);
    final expenses = FakeExpensesController();
    await tester.pumpWidget(testApp(
      overrides: [expensesProvider.overrideWith(() => expenses)],
      open: (context) => showAddExpenseSheet(context, testGroup),
    ));
    await openIt(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Dinner');
    await tester.enterText(find.byType(TextField).at(1), '100');
    await tapButton(tester, l10n.addExpense);

    expect(expenses.added, hasLength(1));
    final saved = expenses.added.single;
    expect(saved['title'], 'Dinner');
    expect(saved['amount'], 100.0);
    expect(saved['paidBy'], ali);
    expect(saved['splits'], [
      {'user_id': ali, 'amount_owed': 50.0},
      {'user_id': bilal, 'amount_owed': 50.0},
    ]);
    // The sheet closed with a success message
    expect(find.text(l10n.expenseAdded), findsOneWidget);
  });

  testWidgets('add expense: no title → message, nothing saved', (tester) async {
    useTallScreen(tester);
    final expenses = FakeExpensesController();
    await tester.pumpWidget(testApp(
      overrides: [expensesProvider.overrideWith(() => expenses)],
      open: (context) => showAddExpenseSheet(context, testGroup),
    ));
    await openIt(tester);

    await tester.enterText(find.byType(TextField).at(1), '100');
    await tapButton(tester, l10n.addExpense);

    expect(expenses.added, isEmpty);
    expect(find.text(l10n.pleaseEnterTitle), findsOneWidget);
  });

  testWidgets('edit expense: open from the detail sheet, change the amount',
      (tester) async {
    useTallScreen(tester);
    final expense = ExpenseModel.fromMap({
      'id': 'e1', 'group_id': 'g1', 'paid_by': ali, 'paid_by_name': 'Ali',
      'title': 'Dinner', 'amount': 300, 'split_type': 'equal',
      'created_at': '2026-10-01T12:00:00Z', 'expense_date': '2026-10-01',
      'expense_splits': [
        {'id': 's1', 'expense_id': 'e1', 'user_id': ali, 'user_name': 'Ali', 'amount_owed': 150},
        {'id': 's2', 'expense_id': 'e1', 'user_id': bilal, 'user_name': 'Bilal', 'amount_owed': 150},
      ],
    });
    final expenses = FakeExpensesController([expense]);
    await tester.pumpWidget(testApp(
      overrides: [
        expensesProvider.overrideWith(() => expenses),
        settlementsProvider.overrideWith((ref, groupId) async => const []),
      ],
      open: (context) => showExpenseDetailSheet(context, expense, testGroup),
    ));
    await openIt(tester);

    await tapButton(tester, l10n.editExpense);
    // The form is filled in from the expense
    expect(find.text(l10n.editExpense), findsWidgets);
    expect(find.widgetWithText(TextField, 'Dinner'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '400');
    await tapButton(tester, l10n.saveChanges);

    expect(expenses.edited, hasLength(1));
    final saved = expenses.edited.single;
    expect(saved['id'], 'e1');
    expect(saved['amount'], 400.0);
    expect(saved['splits'], [
      {'user_id': ali, 'amount_owed': 200.0},
      {'user_id': bilal, 'amount_owed': 200.0},
    ]);
    expect(find.text(l10n.expenseUpdated), findsOneWidget);
  });

  testWidgets('settle up: Ali records paying Bilal 40 of the 100 he owes',
      (tester) async {
    useTallScreen(tester);
    late FakeSettleUpController settle;
    await tester.pumpWidget(testApp(
      overrides: [
        settleUpProvider.overrideWith((ref) => settle = FakeSettleUpController(ref)),
      ],
      open: (context) => showSettleUpSheet(
        context,
        const DebtModel(
          fromUserId: ali, fromUserName: 'Ali',
          toUserId: bilal, toUserName: 'Bilal',
          amount: 100, currency: 'PKR', groupId: 'g1', groupName: 'Flat',
        ),
      ),
    ));
    await openIt(tester);

    await tester.enterText(find.byType(TextField), '40');
    await tapButton(tester, l10n.iPaid);

    expect(settle.recorded, [
      {'groupId': 'g1', 'paidBy': ali, 'paidTo': bilal, 'amount': 40.0},
    ]);
  });

  testWidgets('settle up: Bilal confirms the pending payment', (tester) async {
    useTallScreen(tester);
    late FakeSettleUpController settle;
    final pending = SettlementModel(
      id: 'st1', groupId: 'g1',
      paidBy: ali, paidByName: 'Ali', paidTo: bilal, paidToName: 'Bilal',
      amount: 40, currency: 'PKR', status: 'pending',
      createdAt: DateTime(2026, 10, 2),
    );
    await tester.pumpWidget(testApp(
      signedInAs: bilal,
      overrides: [
        settleUpProvider.overrideWith((ref) => settle = FakeSettleUpController(ref)),
        settlementsProvider.overrideWith((ref, groupId) async => [pending]),
      ],
      open: (context) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SettlementHistoryScreen(group: testGroup)),
      ),
    ));
    await openIt(tester);

    await tester.tap(find.text(l10n.confirmPayment));
    await tester.pumpAndSettle();
    expect(settle.confirmed, ['st1']);
  });

  testWidgets('settle up: Ali (the payer) cannot confirm his own payment',
      (tester) async {
    useTallScreen(tester);
    final pending = SettlementModel(
      id: 'st1', groupId: 'g1',
      paidBy: ali, paidByName: 'Ali', paidTo: bilal, paidToName: 'Bilal',
      amount: 40, currency: 'PKR', status: 'pending',
      createdAt: DateTime(2026, 10, 2),
    );
    await tester.pumpWidget(testApp(
      overrides: [
        settlementsProvider.overrideWith((ref, groupId) async => [pending]),
      ],
      open: (context) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SettlementHistoryScreen(group: testGroup)),
      ),
    ));
    await openIt(tester);

    expect(find.text(l10n.confirmPayment), findsNothing);
    expect(find.text(l10n.cancelPayment), findsOneWidget);
  });

  testWidgets('join group: the code is sent, then a success message',
      (tester) async {
    useTallScreen(tester);
    late FakeJoinGroupController join;
    await tester.pumpWidget(testApp(
      overrides: [
        joinGroupProvider.overrideWith((ref) => join = FakeJoinGroupController(ref)),
      ],
      open: showJoinGroupSheet,
    ));
    await openIt(tester);

    await tester.enterText(find.byType(TextField), '  abc12345 ');
    await tapButton(tester, l10n.joinGroup);

    expect(join.codes, ['abc12345']);
    expect(find.text(l10n.youJoinedGroup), findsOneWidget);
  });

  testWidgets('join group: a wrong code shows a message', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp(
      overrides: [
        joinGroupProvider.overrideWith((ref) => FakeJoinGroupController(ref)),
      ],
      open: showJoinGroupSheet,
    ));
    await openIt(tester);

    await tester.enterText(find.byType(TextField), 'wrong');
    await tapButton(tester, l10n.joinGroup);

    expect(find.text(l10n.invalidInviteCode), findsOneWidget);
  });
}
