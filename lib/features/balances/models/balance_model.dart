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

  const DebtModel({
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.amount,
    required this.currency,
    required this.groupId,
    required this.groupName,
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
  final List<DebtModel> debts; // simplified debt list

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