import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

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

  // Key for groupBalanceSummaryProvider (a record compares by value)
  ({String id, String name, String currency}) get balanceKey =>
      (id: id, name: name, currency: currency);

  GroupModel copyWith({String? photoUrl}) => GroupModel(
        id: id,
        name: name,
        description: description,
        currency: currency,
        createdBy: createdBy,
        inviteCode: inviteCode,
        isArchived: isArchived,
        createdAt: createdAt,
        category: category,
        photoUrl: photoUrl ?? this.photoUrl,
        memberCount: memberCount,
      );

  // Same keys as fromMap reads (for OfflineCache)
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'currency': currency,
        'created_by': createdBy,
        'invite_code': inviteCode,
        'is_archived': isArchived,
        'created_at': createdAt.toIso8601String(),
        'category': category,
        'photo_url': photoUrl,
        'member_count': memberCount,
      };

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
// ── Group types ───────────────────────────────────────────────────────────────
// The ids saved in groups.category (see migration 20261030000300).
const groupTypes = ['home', 'trip', 'friends', 'office', 'family', 'other'];

IconData groupTypeIcon(String? category) => switch (category?.toLowerCase()) {
      'home' => Icons.home_rounded,
      'trip' => Icons.flight_rounded,
      'friends' => Icons.group_rounded,
      'office' => Icons.work_rounded,
      'family' => Icons.favorite_rounded,
      _ => Icons.category_rounded,
    };

String groupTypeLabel(AppLocalizations l10n, String? category) =>
    switch (category?.toLowerCase()) {
      'home' => l10n.groupTypeHome,
      'trip' => l10n.groupTypeTrip,
      'friends' => l10n.groupTypeFriends,
      'office' => l10n.groupTypeOffice,
      'family' => l10n.groupTypeFamily,
      _ => l10n.groupTypeOther,
    };
