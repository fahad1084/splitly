// The "Edit history" lines in the expense detail sheet.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:splitly/core/utils/money_format.dart';
import 'package:splitly/features/expenses/models/expense_model.dart';
import 'package:splitly/features/expenses/screens/expense_detail_sheet.dart';
import 'package:splitly/l10n/app_localizations.dart';

ExpenseEdit edit(Map<String, dynamic> changes) => ExpenseEdit.fromMap({
      'edited_by': 'u1',
      'edited_by_name': 'Ali',
      'edited_at': '2026-10-29T16:40:00Z',
      'changes': changes,
    });

void main() {
  // The app loads date formats through Flutter's localizations; a plain
  // unit test loads them itself.
  setUpAll(() => initializeDateFormatting());

  final en = lookupAppLocalizations(const Locale('en'));
  final ur = lookupAppLocalizations(const Locale('ur'));

  test('amount and split change → two lines with real amounts', () {
    final lines = describeEdit(
        edit({
          'amount': {'from': 300, 'to': 400.5},
          'splits': {
            'from': {'u1': 150, 'u2': 150},
            'to': {'u1': 200.25, 'u2': 200.25},
          },
        }),
        en,
        'PKR');
    expect(lines, [
      en.changeAmount(formatMoney(300, 'PKR'), formatMoney(400.5, 'PKR')),
      en.changeSplit,
    ]);
    expect(lines.first, contains('400.50'));
  });

  test('only what changed is listed, in a fixed order', () {
    final lines = describeEdit(
        edit({
          'notes': {'from': null, 'to': 'cash'},
          'title': {'from': 'Dinner', 'to': 'Dinner out'},
          'date': {'from': '2026-10-01', 'to': '2026-10-02'},
          'category': {'from': 'food', 'to': 'travel'},
        }),
        en,
        'PKR');
    expect(lines, hasLength(4));
    expect(lines[0], 'Title: Dinner → Dinner out');
    expect(lines[1], startsWith('Date: Oct 1, 2026'));
    expect(lines[2], en.changeCategory);
    expect(lines[3], en.changeNotes);
  });

  test('Urdu texts are used in Urdu', () {
    final lines = describeEdit(edit({'split_type': {'from': 'equal', 'to': 'custom'}}), ur, 'PKR');
    expect(lines, [ur.changeSplit]);
  });

  test('a history row is read with the editor name and local time', () {
    final e = edit({});
    expect(e.editedByName, 'Ali');
    expect(e.editedAt.isUtc, isFalse);
    expect(e.changes, isEmpty);
  });
}
