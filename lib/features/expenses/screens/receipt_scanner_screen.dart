import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../security/controllers/app_lock_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RECEIPT TOTAL FINDER (pure, unit-tested in test/receipt_total_test.dart)
// ─────────────────────────────────────────────────────────────────────────────
// A number counts as money when it
//   • has exactly 2 decimals:            17.07   1,234.50   $8.99
//   • has a money sign in front:          Rs 1,250   Rs. 1250   PKR 1250   $8
//   • ends with "/-" (Pakistani bills):   1,250/-   1250/-
//   • or stands on a "Total" line (any number there; the largest wins).
// Plain numbers elsewhere (phone, card, invoice numbers, dates) are ignored.
final _decimalMoney = RegExp(r'(\d{1,3}(?:,\d{3})+|\d+)\.\d{2}(?!\d)');
final _signedMoney = RegExp(
    r'(?<![a-z])(?:rs\.?|pkr|usd|\$)\s*((?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?)(?![\d,])',
    caseSensitive: false);
final _slashDashMoney =
    RegExp(r'((?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?)\s*/-');
final _anyNumber =
    RegExp(r'(?<![\d.,])((?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?)(?![\d,]|\.\d)');

// Strongest first: "Grand Total" beats a plain "Total".
const _strongTotalKeywords = [
  'grand total', 'net total', 'total payable', 'payable', 'amount due',
  'balance due', 'net amount',
];
const _totalKeywords = ['total', 'totai', 't0tal'];
const _subtotalKeywords = ['subtotal', 'sub total', 'sub-total'];
const _maxReceiptAmount = 1000000.0;

double? _parseAmount(String raw) => double.tryParse(raw.replaceAll(',', ''));

// Money values on one line, each number counted once even when two
// patterns match it (e.g. "Rs 1,250.00").
List<double> _moneyOnLine(String line, {required bool anyNumber}) {
  final taken = <(int, int)>[];
  final values = <double>[];
  bool overlaps(int a, int b) => taken.any((t) => a < t.$2 && b > t.$1);

  for (final re in [
    _signedMoney, _slashDashMoney, _decimalMoney,
    if (anyNumber) _anyNumber,
  ]) {
    for (final m in re.allMatches(line)) {
      final g = re == _decimalMoney ? m.group(0)! : m.group(1)!;
      final at = m.start + m.group(0)!.indexOf(g);
      if (overlaps(at, at + g.length)) continue;
      final v = _parseAmount(g);
      if (v == null || v <= 0 || v > _maxReceiptAmount) continue;
      taken.add((at, at + g.length));
      values.add(v);
    }
  }
  return values;
}

@visibleForTesting
double? findReceiptTotal(String text) {
  final lines = text.split('\n');
  final moneyLines = <MapEntry<int, double>>[];
  int? strongLine;
  int? totalLine;
  int? subtotalLine;

  for (var i = 0; i < lines.length; i++) {
    final lower = lines[i].toLowerCase();
    final isSubtotal = _subtotalKeywords.any(lower.contains);
    final isStrong = !isSubtotal && _strongTotalKeywords.any(lower.contains);
    final isTotal =
        !isSubtotal && (isStrong || _totalKeywords.any(lower.contains));

    if (isStrong && strongLine == null) strongLine = i;
    if (isTotal && totalLine == null) totalLine = i;
    if (isSubtotal && subtotalLine == null) subtotalLine = i;

    for (final v in _moneyOnLine(lines[i], anyNumber: isTotal || isSubtotal)) {
      moneyLines.add(MapEntry(i, v));
    }
  }

  if (moneyLines.isEmpty) return null;

  double? largestOn(int? line) {
    if (line == null) return null;
    final vals = moneyLines.where((e) => e.key == line).map((e) => e.value);
    return vals.isEmpty ? null : vals.reduce((a, b) => a > b ? a : b);
  }

  // Priority 1 — on the same line as the strongest "total" keyword
  final onTotalLine = largestOn(strongLine) ?? largestOn(totalLine);
  if (onTotalLine != null) return onTotalLine;

  // Priority 2 — within 6 lines AFTER the "total" keyword (label and value
  // in separate columns). An amount repeated there is very likely the total.
  final keyLine = strongLine ?? totalLine;
  if (keyLine != null) {
    final nearby = moneyLines
        .where((e) => e.key > keyLine && e.key <= keyLine + 6)
        .toList();
    if (nearby.isNotEmpty) {
      final counts = <double, int>{};
      for (final e in nearby) {
        counts[e.value] = (counts[e.value] ?? 0) + 1;
      }
      final repeated = counts.entries.where((e) => e.value > 1).toList()
        ..sort((a, b) => b.value.compareTo(a.value)); // most repeated first
      if (repeated.isNotEmpty) return repeated.first.key;
      return nearby.first.value;
    }
  }

  // Priority 3 — same line as "subtotal"
  final onSubtotal = largestOn(subtotalLine);
  if (onSubtotal != null) return onSubtotal;

  // Priority 4 — the largest money value anywhere
  return moneyLines.map((e) => e.value).reduce((a, b) => a > b ? a : b);
}

class ReceiptScanResult {
  final double? amount;
  final String rawText;
  ReceiptScanResult({this.amount, required this.rawText});
}

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  File? _image;
  bool _scanning = false;
  String _rawText = '';
  final _amountCtrl = TextEditingController();

  Future<void> _pickImage(ImageSource source) async {
    final picked = await AppLockController.runWithoutLock(
        () => ImagePicker().pickImage(source: source, imageQuality: 85));
    if (picked == null) return;
    setState(() {
      _image = File(picked.path);
      _amountCtrl.clear();
    });
    await _scanReceipt();
  }

  Future<void> _scanReceipt() async {
    if (_image == null) return;
    setState(() => _scanning = true);

    final l10n = AppLocalizations.of(context)!;
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(_image!);
      final recognized = await textRecognizer.processImage(inputImage);
      _rawText = recognized.text;

      final found = findReceiptTotal(recognized.text);

      setState(() {
        if (found != null) _amountCtrl.text = found.toStringAsFixed(2);
      });
    } catch (e) {
      if (mounted) showErrorSnack(context, l10n.couldNotReadReceipt);
    } finally {
      await textRecognizer.close();
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final textColor = dark ? AppColors.primaryTint : AppColors.primaryDark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.scanReceipt)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_image == null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 72, color: AppColors.primaryLight.withOpacity(0.6)),
                        const SizedBox(height: 16),
                        Text(
                          l10n.scanReceiptDesc,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textColor.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(_image!, fit: BoxFit.contain, width: double.infinity),
                  ),
                ),

              const SizedBox(height: 16),

              if (_scanning)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                  ),
                ),

              if (!_scanning && _image != null) ...[
                Text(
                  _amountCtrl.text.isEmpty
                      ? l10n.couldNotDetectTotal
                      : l10n.detectedTotalConfirm,
                  style: TextStyle(
                    fontSize: 13,
                    color: _amountCtrl.text.isEmpty ? AppColors.dangerText(context) : AppColors.successText(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: _amountCtrl.text.isEmpty,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: textColor),
                  decoration: InputDecoration(
                    labelText: l10n.totalAmountLabel,
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _amountCtrl.text.trim().isEmpty
                      ? null
                      : () {
                    final val = double.tryParse(_amountCtrl.text.trim());
                    Navigator.pop(
                      context,
                      ReceiptScanResult(amount: val, rawText: _rawText),
                    );
                  },
                  child: Text(l10n.useThisAmount),
                ),
                const SizedBox(height: 10),
              ],

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(_image == null ? l10n.camera : l10n.retake),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_outlined),
                      label: Text(l10n.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}