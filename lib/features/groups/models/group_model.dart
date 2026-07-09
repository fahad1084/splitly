class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String currency;
  final String createdBy;
  final String inviteCode;
  final bool isArchived;
  final DateTime createdAt;
  final String? category;
  final String? photoUrl;      // ✅ new
  final int? memberCount;

  const GroupModel({
    required this.id,
    required this.name,
    this.description,
    required this.currency,
    required this.createdBy,
    required this.inviteCode,
    required this.isArchived,
    required this.createdAt,
    this.category,
    this.photoUrl,             // ✅ new
    this.memberCount,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      currency: map['currency'] as String? ?? 'PKR',
      createdBy: map['created_by'] as String,
      inviteCode: map['invite_code'] as String,
      isArchived: map['is_archived'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      category: map['category'] as String?,
      photoUrl: map['photo_url'] as String?,   // ✅ new
      memberCount: map['member_count'] as int?,
    );
  }
}