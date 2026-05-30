class MessageModel {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String content;
  final String? expenseRef; // optional expense tag
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.expenseRef,
    required this.createdAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      senderId: map['sender_id'] as String,
      senderName: map['sender_name'] as String? ?? 'Unknown',
      content: map['content'] as String,
      expenseRef: map['expense_ref'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }
}