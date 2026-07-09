class MessageModel {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String content;
  final String? expenseRef;
  final String? attachmentUrl;
  final String? attachmentType;
  final int? audioDuration;
  final String? replyToId;       // ✅ new
  final String? replyToContent;  // ✅ new — snippet of replied message
  final String? replyToSender;   // ✅ new — name of who was replied to
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.expenseRef,
    this.attachmentUrl,
    this.attachmentType,
    this.audioDuration,
    this.replyToId,
    this.replyToContent,
    this.replyToSender,
    required this.createdAt,
  });

  bool get isImage => attachmentType == 'image';
  bool get isAudio => attachmentType == 'audio';
  bool get hasAttachment => attachmentUrl != null;
  bool get isReply => replyToId != null;

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      senderId: map['sender_id'] as String,
      senderName: map['sender_name'] as String? ?? 'Unknown',
      content: map['content'] as String,
      expenseRef: map['expense_ref'] as String?,
      attachmentUrl: map['attachment_url'] as String?,
      attachmentType: map['attachment_type'] as String?,
      audioDuration: map['audio_duration'] as int?,
      replyToId: map['reply_to_id'] as String?,
      replyToContent: map['reply_to_content'] as String?,
      replyToSender: map['reply_to_sender'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }
}