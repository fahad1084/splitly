// Fake data and controllers for the flow tests: no Supabase, no internet.
// Each fake records what the screen asked it to do.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:splitly/features/auth/controllers/auth_controller.dart';
import 'package:splitly/features/balances/controllers/balances_controller.dart';
import 'package:splitly/features/expenses/controllers/expenses_controller.dart';
import 'package:splitly/features/expenses/models/expense_model.dart';
import 'package:splitly/features/groups/controllers/groups_controller.dart';
import 'package:splitly/features/groups/models/group_model.dart';
import 'package:splitly/features/groups/screens/join_group_screen.dart';
import 'package:splitly/l10n/app_localizations.dart';

const ali = 'u-ali';
const bilal = 'u-bilal';

final l10n = lookupAppLocalizations(const Locale('en'));

User fakeUser(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    );

final testGroup = GroupModel(
  id: 'g1',
  name: 'Flat',
  currency: 'PKR',
  createdBy: ali,
  inviteCode: 'abc12345',
  isArchived: false,
  createdAt: DateTime(2026, 1, 1),
);

// Rows as groupMembersProvider returns them
List<Map<String, dynamic>> testMembers({String aliRole = 'admin'}) => [
      {
        'user_id': ali,
        'role': aliRole,
        'profiles': {'id': ali, 'full_name': 'Ali', 'avatar_color': '#0F766E'},
      },
      {
        'user_id': bilal,
        'role': 'member',
        'profiles': {'id': bilal, 'full_name': 'Bilal', 'avatar_color': '#EAB308'},
      },
    ];

// ── Expenses ─────────────────────────────────────────────────────────────────
class FakeExpensesController extends ExpensesController {
  FakeExpensesController([this.initial = const []]);
  final List<ExpenseModel> initial;
  final added = <Map<String, dynamic>>[];
  final edited = <Map<String, dynamic>>[];

  @override
  Future<List<ExpenseModel>> build(String arg) async => initial;

  @override
  Future<String?> addExpense({
    required String title,
    required double amount,
    required String category,
    required String paidBy,
    required String splitType,
    required List<Map<String, dynamic>> members,
    required String currency,
    required DateTime expenseDate,
    String? notes,
    bool isRecurring = false,
    String? recurEvery,
  }) async {
    added.add({
      'title': title,
      'amount': amount,
      'paidBy': paidBy,
      'splitType': splitType,
      'splits': calculateSplits(
          amount: amount, splitType: splitType, members: members),
    });
    return null;
  }

  @override
  Future<String?> editExpense({
    required String expenseId,
    required String title,
    required double amount,
    required String category,
    required String splitType,
    required List<Map<String, dynamic>> members,
    required DateTime expenseDate,
    String? notes,
  }) async {
    edited.add({
      'id': expenseId,
      'title': title,
      'amount': amount,
      'splits': calculateSplits(
          amount: amount, splitType: splitType, members: members),
    });
    return null;
  }
}

// ── Payments ─────────────────────────────────────────────────────────────────
class FakeSettleUpController extends SettleUpController {
  FakeSettleUpController(super.ref);
  final recorded = <Map<String, dynamic>>[];
  final confirmed = <String>[];

  @override
  Future<String?> recordSettlement({
    required String groupId,
    required String paidBy,
    required String paidTo,
    required double amount,
  }) async {
    recorded.add(
        {'groupId': groupId, 'paidBy': paidBy, 'paidTo': paidTo, 'amount': amount});
    return null;
  }

  @override
  Future<String?> confirmSettlement(String groupId, String settlementId) async {
    confirmed.add(settlementId);
    return null;
  }
}

// ── Joining ──────────────────────────────────────────────────────────────────
class FakeJoinGroupController extends JoinGroupController {
  FakeJoinGroupController(super.ref);
  final codes = <String>[];

  @override
  Future<String?> joinGroup(String inviteCode) async {
    codes.add(inviteCode);
    return inviteCode == 'wrong' ? 'INVALID_CODE' : null;
  }
}

// ── Test app ─────────────────────────────────────────────────────────────────
// English, the given overrides, and a button that opens [open].
Widget testApp({
  required List<Override> overrides,
  required void Function(BuildContext context) open,
  String signedInAs = ali,
}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(fakeUser(signedInAs)),
      groupMembersProvider.overrideWith((ref, groupId) async => testMembers()),
      ...overrides,
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

// A tall phone screen, so long sheets fit
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}
