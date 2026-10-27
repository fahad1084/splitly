// Receipt total finder (receipt_scanner_screen.dart). Pure text in, amount
// out — no camera or ML Kit needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:splitly/features/expenses/screens/receipt_scanner_screen.dart';

void main() {
  group('amounts without decimals or with commas', () {
    test('"Rs 1,250"', () {
      expect(findReceiptTotal('Biryani\nTotal Rs 1,250'), 1250);
    });

    test('"Rs. 1250"', () {
      expect(findReceiptTotal('Chai 2x\nTotal Rs. 1250\nThank you'), 1250);
    });

    test('"1,250/-"', () {
      expect(findReceiptTotal('Karahi\nTotal 1,250/-'), 1250);
    });

    test('"PKR1250" and "\$8" without a space', () {
      expect(findReceiptTotal('Total PKR1250'), 1250);
      expect(findReceiptTotal('Coffee\nTotal \$8'), 8);
    });

    test('keeps decimals: "Rs 1,250.50"', () {
      expect(findReceiptTotal('Total Rs 1,250.50'), 1250.50);
    });
  });

  group('prefers the Total line', () {
    test('Total beats a bigger item price', () {
      const text = 'Item A Rs 2,000\nDiscount Rs 900\nTotal Rs 1,100';
      expect(findReceiptTotal(text), 1100);
    });

    test('Grand Total beats Subtotal and Total', () {
      const text =
          'Subtotal 1,000.00\nTax 170.00\nTotal 1,170.00\nGrand Total 1,200.00';
      expect(findReceiptTotal(text), 1200);
    });

    test('Subtotal is not taken as the total', () {
      const text = 'Subtotal Rs 1,000\nGST Rs 170\nTotal Rs 1,170';
      expect(findReceiptTotal(text), 1170);
    });

    test('plain number on the Total line counts; largest wins', () {
      expect(findReceiptTotal('Total items 3   1,250'), 1250);
    });

    test('value on the line after "Total" (separate columns)', () {
      expect(findReceiptTotal('TOTAL\n1,250/-'), 1250);
    });
  });

  group('ignores numbers that are not money', () {
    test('phone, invoice and date numbers are skipped', () {
      const text = 'Tel 03001234567\nInvoice 88213\n12/05/2026\nRs 450';
      expect(findReceiptTotal(text), 450);
    });

    test('no money at all → null', () {
      expect(findReceiptTotal('Tel 03001234567\nThank you'), isNull);
    });

    test('"Rs 1,250.00" is one amount, not two', () {
      // Same value matched by 2 patterns must not count as "repeated"
      const text = 'TOTAL\nRs 1,250.00\nCash Rs 2,000.00';
      expect(findReceiptTotal(text), 1250);
    });

    test('old 2-decimal receipts still work', () {
      const text = r'Burger $8.99' '\n' r'Fries $3.50' '\n' r'TOTAL $12.49';
      expect(findReceiptTotal(text), 12.49);
    });
  });
}
