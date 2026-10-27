// Represents what one person owes another
class DebtModel {
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final double amount;
  final String currency;
  final String groupId;
  final String groupName;
  // Payments the debtor has recorded but the receiver has not confirmed
  // yet. Shown to the user, but NOT subtracted from [amount].
  final double pendingAmount;

  const DebtModel({
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.amount,
    required this.currency,
    required this.groupId,
    required this.groupName,
    this.pendingAmount = 0,
  });
}

// Summary of balances for a group
class GroupBalanceSummary {
  final String groupId;
  final String groupName;
  final String currency;
  final double totalSpent;
  final double youAreOwed;  // others owe you
  final double youOwe;      // you owe others
  final List<DebtModel> debts; // pairwise debts in this group

  const GroupBalanceSummary({
    required this.groupId,
    required this.groupName,
    required this.currency,
    required this.totalSpent,
    required this.youAreOwed,
    required this.youOwe,
    required this.debts,
  });

  double get netBalance => youAreOwed - youOwe;
}

// One row of the debts the database calculated (get_my_debts RPC)
class DebtRow {
  final String groupId;
  final String debtorId;
  final String debtorName;
  final String creditorId;
  final String creditorName;
  final double amount;
  final double pendingAmount;

  const DebtRow({
    required this.groupId,
    required this.debtorId,
    required this.debtorName,
    required this.creditorId,
    required this.creditorName,
    required this.amount,
    this.pendingAmount = 0,
  });

  // For OfflineCache
  Map<String, dynamic> toMap() => {
        'group_id': groupId,
        'debtor_id': debtorId,
        'debtor_name': debtorName,
        'creditor_id': creditorId,
        'creditor_name': creditorName,
        'amount': amount,
        'pending_amount': pendingAmount,
      };

  factory DebtRow.fromMap(Map<String, dynamic> m) => DebtRow(
        groupId: m['group_id'] as String,
        debtorId: m['debtor_id'] as String,
        debtorName: m['debtor_name'] as String,
        creditorId: m['creditor_id'] as String,
        creditorName: m['creditor_name'] as String,
        amount: (m['amount'] as num).toDouble(),
        pendingAmount: (m['pending_amount'] as num?)?.toDouble() ?? 0,
      );
}

// One payment in a group's payment history
class SettlementModel {
  final String id;
  final String groupId;
  final String paidBy;
  final String paidByName;
  final String paidTo;
  final String paidToName;
  final double amount;
  final String currency;
  final String status; // pending | confirmed | cancelled | legacy
  final DateTime createdAt;

  const SettlementModel({
    required this.id,
    required this.groupId,
    required this.paidBy,
    required this.paidByName,
    required this.paidTo,
    required this.paidToName,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';

  factory SettlementModel.fromMap(
      Map<String, dynamic> map, Map<String, String> names) {
    final paidBy = map['paid_by'] as String;
    final paidTo = map['paid_to'] as String;
    return SettlementModel(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      paidBy: paidBy,
      paidByName: names[paidBy] ?? 'Unknown',
      paidTo: paidTo,
      paidToName: names[paidTo] ?? 'Unknown',
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'PKR',
      status: map['status'] as String? ?? 'confirmed',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
