// Unit tests for calculateSplits() — splits must always add up EXACTLY to
// the expense amount, because the add_expense RPC rejects anything else.

import 'package:flutter_test/flutter_test.dart';
import 'package:splitly/features/expenses/controllers/expenses_controller.dart';

Map<String, dynamic> _m(String id,
    {bool included = true, double custom = 0, double pct = 0}) =>
    {
      'user_id': id,
      'included': included,
      'custom_amount': custom,
      'percentage': pct,
    };

List<double> _amounts(List<Map<String, dynamic>> splits) =>
    splits.map((s) => s['amount_owed'] as double).toList();

int _totalPaisa(List<Map<String, dynamic>> splits) =>
    splits.fold(0, (sum, s) => sum + toPaisa(s['amount_owed'] as double));

void main() {
  group('equal split', () {
    test('100 split 3 ways → 33.34 + 33.33 + 33.33 = 100.00', () {
      final s = calculateSplits(
          amount: 100, splitType: 'equal', members: [_m('a'), _m('b'), _m('c')]);
      expect(_amounts(s), [33.34, 33.33, 33.33]);
      expect(_totalPaisa(s), 10000);
    });

    test('0.05 split 3 ways → leftover paisa go to the first members', () {
      final s = calculateSplits(
          amount: 0.05, splitType: 'equal', members: [_m('a'), _m('b'), _m('c')]);
      expect(_amounts(s), [0.02, 0.02, 0.01]);
    });

    test('members not included get no split', () {
      final s = calculateSplits(
          amount: 90,
          splitType: 'equal',
          members: [_m('a'), _m('b', included: false), _m('c')]);
      expect(s.map((e) => e['user_id']), ['a', 'c']);
      expect(_amounts(s), [45.0, 45.0]);
    });

    test('nobody included → no splits', () {
      final s = calculateSplits(
          amount: 50, splitType: 'equal', members: [_m('a', included: false)]);
      expect(s, isEmpty);
    });
  });

  group('percentage split', () {
    test('33.33 / 33.33 / 33.34 % of 100 adds up exactly', () {
      final s = calculateSplits(
          amount: 100,
          splitType: 'percentage',
          members: [_m('a', pct: 33.33), _m('b', pct: 33.33), _m('c', pct: 33.34)]);
      expect(_totalPaisa(s), 10000);
    });

    test('33.33 x 3 % (= 99.99%) of 100 still splits the WHOLE 100', () {
      final s = calculateSplits(
          amount: 100,
          splitType: 'percentage',
          members: [_m('a', pct: 33.33), _m('b', pct: 33.33), _m('c', pct: 33.33)]);
      expect(_amounts(s), [33.34, 33.33, 33.33]);
      expect(_totalPaisa(s), 10000);
    });

    test('70 / 30 % of 999.99 adds up exactly', () {
      final s = calculateSplits(
          amount: 999.99,
          splitType: 'percentage',
          members: [_m('a', pct: 70), _m('b', pct: 30)]);
      expect(_totalPaisa(s), 99999);
      expect(_amounts(s), [700.0, 299.99]);
    });

    test('50 / 50 % of 0.01 → one paisa to the first member', () {
      final s = calculateSplits(
          amount: 0.01,
          splitType: 'percentage',
          members: [_m('a', pct: 50), _m('b', pct: 50)]);
      expect(_amounts(s), [0.01, 0.0]);
    });
  });

  group('custom split', () {
    test('amounts are kept as typed (rounded to the paisa)', () {
      final s = calculateSplits(
          amount: 100,
          splitType: 'custom',
          members: [_m('a', custom: 70), _m('b', custom: 30.004)]);
      expect(_amounts(s), [70.0, 30.0]);
    });
  });

  group('percentagesAddUp', () {
    test('33.33 x 3 is accepted', () {
      expect(percentagesAddUp([33.33, 33.33, 33.33]), isTrue);
    });
    test('50 + 50 and 33.33 + 33.33 + 33.34 are accepted', () {
      expect(percentagesAddUp([50, 50]), isTrue);
      expect(percentagesAddUp([33.33, 33.33, 33.34]), isTrue);
    });
    test('99% or 101% is rejected', () {
      expect(percentagesAddUp([50, 49]), isFalse);
      expect(percentagesAddUp([50, 51]), isFalse);
    });
    test('33.33 + 33.33 (2 people, 66.66%) is rejected', () {
      expect(percentagesAddUp([33.33, 33.33]), isFalse);
    });
    test('nobody → rejected', () {
      expect(percentagesAddUp([]), isFalse);
    });
  });
}
