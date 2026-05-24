class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String currency;
  final String createdBy;
  final String inviteCode;
  final bool isArchived;
  final DateTime createdAt;
  final int? memberCount; // joined from group_members count

  const GroupModel({
    required this.id,
    required this.name,
    this.description,
    required this.currency,
    required this.createdBy,
    required this.inviteCode,
    required this.isArchived,
    required this.createdAt,
    this.memberCount,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      currency: map['currency'] as String? ?? 'PKR',
      createdBy: map['created_by'] as String,
      inviteCode: map['invite_code'] as String? ?? '',
      isArchived: map['is_archived'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      memberCount: map['member_count'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'currency': currency,
    'created_by': createdBy,
  };
}