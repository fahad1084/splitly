// The copy of groups and balances kept on the phone for offline start.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:splitly/core/services/offline_cache.dart';
import 'package:splitly/features/balances/models/balance_model.dart';
import 'package:splitly/features/groups/models/group_model.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a group survives the trip to the phone and back', () async {
    final group = GroupModel(
      id: 'g1', name: 'Flat', currency: 'PKR', createdBy: 'u1',
      inviteCode: 'abc', isArchived: false,
      createdAt: DateTime.utc(2026, 10, 1, 12), category: 'home',
      memberCount: 3,
    );
    await OfflineCache.save('groups', 'u1', [group.toMap()]);

    final saved = await OfflineCache.load('groups', 'u1') as List;
    final back = GroupModel.fromMap(Map<String, dynamic>.from(saved.first as Map));
    expect(back.id, 'g1');
    expect(back.category, 'home');
    expect(back.memberCount, 3);
    expect(back.createdAt, group.createdAt);
  });

  test('a debt keeps its exact amount (paisa)', () async {
    const row = DebtRow(
      groupId: 'g1', debtorId: 'a', debtorName: 'Ali',
      creditorId: 'b', creditorName: 'Bilal', amount: 333.33, pendingAmount: 10.01,
    );
    await OfflineCache.save('debts', 'u1', [row.toMap()]);

    final saved = await OfflineCache.load('debts', 'u1') as List;
    final back = DebtRow.fromMap(Map<String, dynamic>.from(saved.first as Map));
    expect(back.amount, 333.33);
    expect(back.pendingAmount, 10.01);
    expect(back.debtorName, 'Ali');
  });

  test('each user has their own copy, and sign out clears all', () async {
    await OfflineCache.save('groups', 'u1', ['one']);
    expect(await OfflineCache.load('groups', 'u2'), isNull);

    await OfflineCache.clear();
    expect(await OfflineCache.load('groups', 'u1'), isNull);
  });
}
