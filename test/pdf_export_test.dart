// PDF export with Urdu text. Builds the real PDF (fonts from assets/fonts)
// and fails if any letter had no font to draw it with.
//
// To look at the PDF yourself:
//   flutter test test/pdf_export_test.dart --dart-define=PDF_OUT=urdu_test.pdf

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitly/features/expenses/models/expense_model.dart';
import 'package:splitly/features/expenses/screens/export_service.dart';
import 'package:splitly/features/groups/models/group_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Urdu letters are joined and in drawing order', () {
    // "دوست" drawn left to right: ت(final) س(initial — و never joins forward) و د
    final drawn = urduForDrawing('دوست');
    expect(drawn.runes.toList(), [0xFE96, 0xFEB3, 0x0648, 0x062F]);
    // Two words: the FIRST word ends up on the RIGHT
    expect(urduForDrawing('علی احمد').split(' ').last,
        urduForDrawing('علی'));
    // Latin text is left alone
    expect(urduForDrawing('Petrol'), 'Petrol');
  });

  test('Urdu group and member names get a font (no missing glyphs)', () async {
    final group = GroupModel.fromMap({
      'id': 'g1',
      'name': 'دوستوں کا گروپ',
      'currency': 'PKR',
      'created_by': 'u1',
      'invite_code': 'ABC123',
      'created_at': '2026-10-01T12:00:00Z',
    });
    final expenses = [
      ExpenseModel.fromMap({
        'id': 'e1',
        'group_id': 'g1',
        'paid_by': 'u1',
        'paid_by_name': 'علی احمد',
        'title': 'بریانی اور چائے',
        'amount': 1250.5,
        'created_at': '2026-10-01T12:00:00Z',
        'expense_splits': [],
      }),
      ExpenseModel.fromMap({
        'id': 'e2',
        'group_id': 'g1',
        'paid_by': 'u2',
        'paid_by_name': 'Bilal',
        'title': 'Petrol',
        'amount': 3000,
        'created_at': '2026-10-02T12:00:00Z',
        'expense_splits': [],
      }),
    ];

    // The pdf package print()s a warning for every letter it can't draw
    final warnings = <String>[];
    final bytes = await runZoned(
      () => ExportService.buildPdf(group: group, expenses: expenses),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => warnings.add(line),
      ),
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(warnings.where((w) => w.contains('Unable to find a font')), isEmpty,
        reason: warnings.join('\n'));

    const out = String.fromEnvironment('PDF_OUT');
    if (out.isNotEmpty) await File(out).writeAsBytes(bytes);
  });
}
