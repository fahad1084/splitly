// Small, self-contained tests that need no Supabase or Firebase connection.
// Replaces the default Flutter counter test (which tested a widget this app
// doesn't have, so it always failed).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:splitly/core/widgets/shared_widgets.dart';
import 'package:splitly/features/expenses/models/expense_model.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('SplitlyButton', () {
    testWidgets('shows its label and calls onPressed when tapped',
        (WidgetTester tester) async {
      var taps = 0;
      await tester.pumpWidget(
          _wrap(SplitlyButton(label: 'Save', onPressed: () => taps++)));

      expect(find.text('Save'), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));
      expect(taps, 1);
    });

    testWidgets('shows a spinner and ignores taps while loading',
        (WidgetTester tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(SplitlyButton(
          label: 'Save', isLoading: true, onPressed: () => taps++)));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      await tester.tap(find.byType(ElevatedButton));
      expect(taps, 0);
    });
  });

  group('ExpenseModel.fromMap', () {
    test('parses an expense with its splits', () {
      final expense = ExpenseModel.fromMap({
        'id': 'e1',
        'group_id': 'g1',
        'paid_by': 'u1',
        'paid_by_name': 'Ali',
        'title': 'Dinner',
        'amount': 300,
        'created_at': '2026-10-01T12:00:00Z',
        'expense_splits': [
          {
            'id': 's1',
            'expense_id': 'e1',
            'user_id': 'u2',
            'user_name': 'Bilal',
            'amount_owed': 150.5,
            'is_settled': false,
          },
        ],
      });

      expect(expense.title, 'Dinner');
      expect(expense.amount, 300.0);
      // Defaults when the columns are missing
      expect(expense.currency, 'PKR');
      expect(expense.splitType, 'equal');
      expect(expense.splits, hasLength(1));
      expect(expense.splits.first.userName, 'Bilal');
      expect(expense.splits.first.amountOwed, 150.5);
      expect(expense.splits.first.isSettled, isFalse);
    });
  });
}
