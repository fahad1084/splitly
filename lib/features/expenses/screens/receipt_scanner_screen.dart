import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';

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

  // Matches money-formatted numbers: 17.07, $8.99, 1,234.50 — always 2 decimals.
  // This is far more reliable than plain digit matching because auth numbers,
  // card numbers, phone numbers, dates never have exactly 2 decimal places.
  final _moneyRegex = RegExp(r'\$?\s?(\d{1,3}(?:,\d{3})*|\d+)\.\d{2}\b');

  final _totalKeywords = ['total', 'totai', 't0tal', 'grand total', 'amount due', 'net amount', 'balance due'];
  final _subtotalKeywords = ['subtotal', 'sub total', 'sub-total'];

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
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

      print('##### OCR LINES #####');
      final splitLines = recognized.text.split('\n');
      for (int i = 0; i < splitLines.length; i++) {
        print('LINE[$i]: ${splitLines[i]}');
      }

      final found = _findTotal(recognized.text);
      print('##### FINAL DETECTED AMOUNT: $found #####');

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

  double? _parseMoneyMatch(RegExpMatch m) {
    final raw = m.group(0)?.replaceAll(r'$', '').replaceAll(',', '').trim();
    return double.tryParse(raw ?? '');
  }

  double? _findTotal(String text) {
    final lines = text.split('\n');

    // Collect every money-formatted number with its line index
    final List<MapEntry<int, double>> moneyLines = [];
    int? totalKeywordLine;
    int? subtotalKeywordLine;

    for (int i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();

      final isSubtotal = _subtotalKeywords.any((k) => lower.contains(k));
      final isTotal = !isSubtotal && _totalKeywords.any((k) => lower.contains(k));

      if (isTotal && totalKeywordLine == null) totalKeywordLine = i;
      if (isSubtotal && subtotalKeywordLine == null) subtotalKeywordLine = i;

      for (final m in _moneyRegex.allMatches(lines[i])) {
        final val = _parseMoneyMatch(m);
        if (val == null || val <= 0 || val > 1000000) continue;
        moneyLines.add(MapEntry(i, val));
      }
    }

    if (moneyLines.isEmpty) return null;

    // Priority 1 — money value on the SAME line as "total" keyword
    if (totalKeywordLine != null) {
      final sameLine = moneyLines.where((e) => e.key == totalKeywordLine);
      if (sameLine.isNotEmpty) return sameLine.first.value;
    }

    // Priority 2 — money value within 6 lines AFTER the "total" keyword
    // (handles receipts where label and value are in separate columns)
    if (totalKeywordLine != null) {
      final nearby = moneyLines
          .where((e) => e.key > totalKeywordLine! && e.key <= totalKeywordLine + 6)
          .toList();
      if (nearby.isNotEmpty) {
        // If the same amount appears more than once nearby, it's very likely the total
        final counts = <double, int>{};
        for (final e in nearby) {
          counts[e.value] = (counts[e.value] ?? 0) + 1;
        }
        final repeated = counts.entries.where((e) => e.value > 1).toList();
        if (repeated.isNotEmpty) {
          repeated.sort((a, b) => b.value.compareTo(a.value));
          return repeated.first.key;
        }
        return nearby.first.value;
      }
    }

    // Priority 3 — same line as "subtotal" keyword
    if (subtotalKeywordLine != null) {
      final sameLine = moneyLines.where((e) => e.key == subtotalKeywordLine);
      if (sameLine.isNotEmpty) return sameLine.first.value;
    }

    // Priority 4 — fallback: the largest money-formatted value anywhere
    // (total is usually the largest single amount on a receipt)
    final values = moneyLines.map((e) => e.value).toList()..sort();
    return values.last;
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
                    color: _amountCtrl.text.isEmpty ? AppColors.danger : AppColors.success,
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