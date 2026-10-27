class ExpenseModel {
  final String id;
  final String groupId;
  final String paidBy;
  final String paidByName;
  final String title;
  final double amount;
  final String currency;
  final String category;
  final String splitType;
  final String? receiptUrl;
  final String? notes;
  final DateTime createdAt;
  // The day the money was spent (picked by the user). Lists, reports and
  // exports use this; createdAt is when the expense was saved.
  final DateTime expenseDate;
  final DateTime? editedAt; // set when someone edited the expense
  final bool isRecurring;
  final String? recurEvery;
  final List<ExpenseSplit> splits;

  const ExpenseModel({
    required this.id,
    required this.groupId,
    required this.paidBy,
    required this.paidByName,
    required this.title,
    required this.amount,
    required this.currency,
    required this.category,
    required this.splitType,
    this.receiptUrl,
    this.notes,
    required this.createdAt,
    required this.expenseDate,
    this.editedAt,
    this.isRecurring = false,
    this.recurEvery,
    required this.splits,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    final splitsList = (map['expense_splits'] as List? ?? [])
        .map((s) => ExpenseSplit.fromMap(Map<String, dynamic>.from(s)))
        .toList();
    final createdAt = DateTime.parse(map['created_at'] as String).toLocal();

    return ExpenseModel(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      paidBy: map['paid_by'] as String,
      paidByName: map['paid_by_name'] as String? ?? 'Someone',
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'PKR',
      category: map['category'] as String? ?? 'other',
      splitType: map['split_type'] as String? ?? 'equal',
      receiptUrl: map['receipt_url'] as String?,
      notes: map['notes'] as String?,
      createdAt: createdAt,
      expenseDate: map['expense_date'] != null
          ? DateTime.parse(map['expense_date'] as String) // 'yyyy-MM-dd'
          : DateTime(createdAt.year, createdAt.month, createdAt.day),
      editedAt: map['edited_at'] != null
          ? DateTime.parse(map['edited_at'] as String).toLocal()
          : null,
      isRecurring: map['is_recurring'] as bool? ?? false,
      recurEvery: map['recur_every'] as String?,
      splits: splitsList,
    );
  }
}

class ExpenseSplit {
  final String id;
  final String expenseId;
  final String userId;
  final String userName;
  final double amountOwed;
  final bool isSettled;

  const ExpenseSplit({
    required this.id,
    required this.expenseId,
    required this.userId,
    required this.userName,
    required this.amountOwed,
    required this.isSettled,
  });

  factory ExpenseSplit.fromMap(Map<String, dynamic> map) {
    return ExpenseSplit(
      id: map['id'] as String,
      expenseId: map['expense_id'] as String,
      userId: map['user_id'] as String,
      userName: map['user_name'] as String? ?? 'Unknown',
      amountOwed: (map['amount_owed'] as num).toDouble(),
      isSettled: map['is_settled'] as bool? ?? false,
    );
  }
}

const expenseCategories = [
  {'id': 'food', 'label': 'Food', 'icon': '🍕'},
  {'id': 'ration', 'label': 'Ration', 'icon': '🛒'},
  {'id': 'utilities', 'label': 'Utilities', 'icon': '💡'},
  {'id': 'transport', 'label': 'Transport', 'icon': '🚗'},
  {'id': 'rent', 'label': 'Rent', 'icon': '🏠'},
  {'id': 'entertainment', 'label': 'Fun', 'icon': '🎮'},
  {'id': 'medicine', 'label': 'Medicine', 'icon': '💊'},
  {'id': 'travel', 'label': 'Travel', 'icon': '✈️'},
  {'id': 'other', 'label': 'Other', 'icon': '📦'},
];