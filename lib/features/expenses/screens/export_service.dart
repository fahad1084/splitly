import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// The pdf package's own Arabic-letter joining. Not exported, but needed:
// by default the package only reorders Urdu right-to-left and leaves every
// letter in its stand-alone form (د و س ت instead of دوست).
// ignore: implementation_imports
import 'package:pdf/src/pdf/font/arabic.dart' as arabic;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../groups/models/group_model.dart';
import '../../expenses/models/expense_model.dart';
import '../controllers/expenses_controller.dart' show dateOnly;
import '../../security/controllers/app_lock_controller.dart';
import '../../../core/utils/money_format.dart';

// Urdu / Arabic letters
final _rtlChars = RegExp(r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]');

// Urdu text, ready to draw: letters joined (initial / medial / final
// shapes) and in DRAWING order, left to right. The pdf package's own
// right-to-left mode would undo the joining, so the text is drawn LTR and
// aligned right instead.
// arabic.convert(word) returns a word joined and already reversed; the
// word order is reversed here, so the first word ends up on the right.
@visibleForTesting
String urduForDrawing(String text) => text
    .split(' ')
    .map((w) => _rtlChars.hasMatch(w) ? arabic.convert(w) : w)
    .toList()
    .reversed
    .join(' ');

pw.Widget _text(String text, {pw.TextStyle? style}) {
  if (!_rtlChars.hasMatch(text)) return pw.Text(text, style: style);
  return pw.Text(
    urduForDrawing(text),
    textDirection: pw.TextDirection.ltr,
    textAlign: pw.TextAlign.right,
    style: style,
  );
}

class ExportService {
  // ── PDF Export ──────────────────────────────────────────────────────────
  static Future<void> exportToPdf({
    required GroupModel group,
    required List<ExpenseModel> expenses,
  }) async {
    final bytes = await buildPdf(group: group, expenses: expenses);
    await AppLockController.runWithoutLock(() => Printing.sharePdf(
        bytes: bytes, filename: '${group.name}_summary.pdf'));
  }

  // Helvetica (built in) has no Urdu letters, and Noto Naskh Arabic has no
  // Latin ones — so Helvetica is the main font and Noto Naskh the fallback.
  static Future<pw.ThemeData> _theme() async {
    final naskh = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf'));
    final naskhBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoNaskhArabic-Bold.ttf'));
    return pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      fontFallback: [naskh, naskhBold],
    );
  }

  static Future<Uint8List> buildPdf({
    required GroupModel group,
    required List<ExpenseModel> expenses,
  }) async {
    final doc = pw.Document(theme: await _theme());
    final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          // ── Header ──────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF134E4A)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Splitly',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold)),
                _text(group.name,
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 14)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── Summary ─────────────────────────────────────────────
          pw.Text('Expense Summary',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Total expenses: ${expenses.length}'),
          pw.Text('Total amount: ${formatMoney(total, group.currency)}'),
          pw.SizedBox(height: 16),

          // ── Table ───────────────────────────────────────────────
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFCCFBF1)),
                children: [
                  _cell('Title', bold: true),
                  _cell('Category', bold: true),
                  _cell('Paid By', bold: true),
                  _cell('Amount', bold: true),
                ],
              ),
              ...expenses.map((e) => pw.TableRow(
                children: [
                  _cell(e.title),
                  _cell(e.category),
                  _cell(e.paidByName),
                  _cell(formatMoney(e.amount, e.currency)),
                ],
              )),
            ],
          ),

          pw.SizedBox(height: 24),
          pw.Text(
            'Generated by Splitly - Your Circle. Your Hisaab.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: _text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );

  // ── CSV Export ──────────────────────────────────────────────────────────
  static Future<void> exportToCsv({
    required GroupModel group,
    required List<ExpenseModel> expenses,
  }) async {
    final rows = <List<dynamic>>[
      ['Title', 'Category', 'Paid By', 'Amount', 'Currency', 'Date'],
      ...expenses.map((e) => [
        e.title,
        e.category,
        e.paidByName,
        e.amount.toStringAsFixed(2),
        e.currency,
        dateOnly(e.expenseDate),
      ]),
    ];

    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${group.name}_expenses.csv');
    await file.writeAsString(csvData);

    await AppLockController.runWithoutLock(() => Share.shareXFiles(
          [XFile(file.path)],
          text: 'Splitly expense export for ${group.name}',
        ));
  }
}