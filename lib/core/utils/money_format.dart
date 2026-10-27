import 'package:intl/intl.dart';

// ── Money display ─────────────────────────────────────────────────────────────
// One place for how money looks in the app, the PDF, shares and the widget:
// always 2 decimals with thousands separators ("PKR 1,250.00"), worked out
// from whole paisa so no floating-point leftovers show up.

final _wholeFormat = NumberFormat('#,##0', 'en_US');

/// Paisa → "1,250.00" (no currency).
String formatPaisaAmount(int paisa) {
  final sign = paisa < 0 ? '-' : '';
  final abs = paisa.abs();
  final cents = (abs % 100).toString().padLeft(2, '0');
  return '$sign${_wholeFormat.format(abs ~/ 100)}.$cents';
}

/// Paisa → "PKR 1,250.00".
String formatPaisa(int paisa, String currency) =>
    '$currency ${formatPaisaAmount(paisa)}';

/// Amount → "PKR 1,250.00" (rounded to the nearest paisa first).
String formatMoney(double amount, String currency) =>
    formatPaisa((amount * 100).round(), currency);

/// Amount → "1,250.00" (no currency).
String formatAmount(double amount) => formatPaisaAmount((amount * 100).round());

/// Totals that must never be added across currencies:
/// {'PKR': 500000, 'USD': 2000} → "PKR 5,000.00 · USD 20.00".
/// Zero currencies are left out; nothing at all → "<fallback> 0.00".
String formatTotals(Map<String, int> paisaByCurrency,
    {String fallbackCurrency = 'PKR', String separator = ' · '}) {
  final parts = (paisaByCurrency.entries.where((e) => e.value != 0).toList()
        ..sort((a, b) => a.key.compareTo(b.key)))
      .map((e) => formatPaisa(e.value, e.key))
      .toList();
  return parts.isEmpty ? formatPaisa(0, fallbackCurrency) : parts.join(separator);
}

/// Adds [amount] (in currency units) to [totals] under [currency], in paisa.
void addToTotals(Map<String, int> totals, String currency, double amount) {
  totals[currency] = (totals[currency] ?? 0) + (amount * 100).round();
}
