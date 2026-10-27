import 'package:flutter_test/flutter_test.dart';
import 'package:splitly/core/utils/money_format.dart';

void main() {
  group('formatPaisa / formatMoney', () {
    test('2 decimals and thousands separators', () {
      expect(formatPaisa(125000, 'PKR'), 'PKR 1,250.00');
      expect(formatPaisa(123456789, 'PKR'), 'PKR 1,234,567.89');
      expect(formatPaisa(5, 'USD'), 'USD 0.05');
      expect(formatPaisa(0, 'PKR'), 'PKR 0.00');
    });

    test('negative amounts keep the sign in front', () {
      expect(formatPaisa(-125050, 'PKR'), 'PKR -1,250.50');
    });

    test('doubles are rounded to the nearest paisa', () {
      expect(formatMoney(33.333333, 'PKR'), 'PKR 33.33');
      expect(formatMoney(0.1 + 0.2, 'PKR'), 'PKR 0.30');
      expect(formatMoney(1250, 'PKR'), 'PKR 1,250.00');
      expect(formatAmount(99.996), '100.00');
    });
  });

  group('formatTotals', () {
    test('never adds different currencies together', () {
      final totals = <String, int>{};
      addToTotals(totals, 'PKR', 3000);
      addToTotals(totals, 'USD', 20);
      addToTotals(totals, 'PKR', 2000);
      expect(totals, {'PKR': 500000, 'USD': 2000});
      expect(formatTotals(totals), 'PKR 5,000.00 · USD 20.00');
    });

    test('leaves out zero currencies; nothing → fallback 0.00', () {
      expect(formatTotals({'PKR': 0, 'USD': 150}), 'USD 1.50');
      expect(formatTotals({}), 'PKR 0.00');
      expect(formatTotals({'EUR': 0}, fallbackCurrency: 'EUR'), 'EUR 0.00');
    });

    test('a negative net stays per currency', () {
      expect(formatTotals({'PKR': -10000, 'USD': 500}),
          'PKR -100.00 · USD 5.00');
    });
  });
}
