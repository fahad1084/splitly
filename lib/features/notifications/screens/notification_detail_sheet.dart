import 'package:flutter/material.dart';
import 'package:splitly/core/widgets/shared_widgets.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../../config/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../groups/models/group_model.dart';
import '../../groups/screens/group_detail_screen.dart';
import '../controllers/notifications_controller.dart';

Future<void> showNotificationDetailSheet(
    BuildContext context, AppNotification notification) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _NotificationDetailSheet(notification: notification),
  );
}

class _NotificationDetailSheet extends StatefulWidget {
  final AppNotification notification;
  const _NotificationDetailSheet({required this.notification});

  @override
  State<_NotificationDetailSheet> createState() =>
      _NotificationDetailSheetState();
}

class _NotificationDetailSheetState extends State<_NotificationDetailSheet> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _notFound = false;
  GroupModel? _group;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final n = widget.notification;
    try {
      if (n.groupId != null) {
        final g = await SupabaseConfig.client
            .from('groups')
            .select('*')
            .eq('id', n.groupId!)
            .maybeSingle();
        if (g != null) _group = GroupModel.fromMap(Map<String, dynamic>.from(g));
      }

      if (n.entityId == null) {
        setState(() => _loading = false);
        return;
      }

      Map<String, dynamic>? row;
      switch (n.type) {
        case 'expense':
          row = await SupabaseConfig.client
              .from('expenses')
              .select('*, profiles!paid_by(full_name, avatar_url, avatar_color)')
              .eq('id', n.entityId!)
              .maybeSingle();
          break;
        case 'message':
          row = await SupabaseConfig.client
              .from('messages')
              .select('*, profiles!sender_id(full_name, avatar_url, avatar_color)')
              .eq('id', n.entityId!)
              .maybeSingle();
          break;
        case 'settlement':
          row = await SupabaseConfig.client
              .from('settlements')
              .select(
              '*, from_profile:profiles!paid_by(full_name, avatar_url, avatar_color), to_profile:profiles!paid_to(full_name, avatar_url, avatar_color)')
              .eq('id', n.entityId!)
              .maybeSingle();
          break;
        case 'member_joined':
          row = await SupabaseConfig.client
              .from('group_members')
              .select('*, profiles(full_name, avatar_url, avatar_color)')
              .eq('id', n.entityId!)
              .maybeSingle();
          break;
      }

      if (mounted) {
        setState(() {
          _data = row == null ? null : Map<String, dynamic>.from(row!);
          _notFound = row == null;
          _loading = false;
        });
      }
    } catch (e) {
      print('=== NOTIFICATION DETAIL FETCH ERROR: $e ===');
      if (mounted) {
        setState(() {
          _loading = false;
          _notFound = true;
        });
      }
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AppColors.primary;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year}, $h:$min $ampm';
  }

  Widget _personRow(BuildContext context, Map<String, dynamic>? profile,
      {String? fallbackName}) {
    final dark = isDark(context);
    final name = profile?['full_name'] as String? ?? fallbackName ?? 'Unknown';
    final avatarUrl = profile?['avatar_url'] as String?;
    final avatarColor = profile?['avatar_color'] as String?;
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: _parseColor(avatarColor),
          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
              ? NetworkImage(avatarUrl)
              : null,
          child: (avatarUrl == null || avatarUrl.isEmpty)
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 13))
              : null,
        ),
        const SizedBox(width: 10),
        Text(name,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: dark ? AppColors.primaryTint : AppColors.primaryDark)),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {Color? valueColor}) {
    final dark = isDark(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryLight.withOpacity(0.8))),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: valueColor ??
                        (dark ? AppColors.primaryTint : AppColors.primaryDark))),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final n = widget.notification;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_notFound || _data == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n.title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryTint)),
            const SizedBox(height: 6),
            Text(n.body,
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryLight.withOpacity(0.9))),
            const SizedBox(height: 10),
            Text(_formatDate(n.createdAt),
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryLight.withOpacity(0.6))),
          ],
        ),
      );
    }

    switch (n.type) {
      case 'expense':
        final profile = _data!['profiles'] as Map<String, dynamic>?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _personRow(context, profile),
            const SizedBox(height: 14),
            Text(_data!['title'] as String? ?? '',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryTint)),
            const SizedBox(height: 4),
            Text(
              '${_data!['currency'] ?? ''} ${_data!['amount']}',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
            const Divider(height: 28, color: AppColors.primaryTint),
            _row(context, l10n.category, '${_data!['category'] ?? '-'}'),
            _row(context, l10n.split, '${_data!['split_type'] ?? '-'}'),
            if (_data!['notes'] != null &&
                (_data!['notes'] as String).isNotEmpty)
              _row(context, l10n.notes, _data!['notes'] as String),
            _row(context, 'Time',
                _formatDate(DateTime.parse(_data!['created_at'] as String))),
          ],
        );

      case 'message':
        final profile = _data!['profiles'] as Map<String, dynamic>?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _personRow(context, profile),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                (_data!['content'] as String?)?.isNotEmpty == true
                    ? _data!['content'] as String
                    : '📎 Attachment',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.primaryTint),
              ),
            ),
            const SizedBox(height: 10),
            _row(context, 'Time',
                _formatDate(DateTime.parse(_data!['created_at'] as String))),
          ],
        );

      case 'settlement':
        final from = _data!['from_profile'] as Map<String, dynamic>?;
        final to = _data!['to_profile'] as Map<String, dynamic>?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _personRow(context, from)),
                const Icon(Icons.arrow_forward_rounded,
                    color: AppColors.primaryLight, size: 18),
                Expanded(child: _personRow(context, to)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${_data!['currency'] ?? ''} ${_data!['amount']}',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
            const Divider(height: 28, color: AppColors.primaryTint),
            _row(context, 'Time',
                _formatDate(DateTime.parse(_data!['created_at'] as String))),
          ],
        );

      case 'member_joined':
        final profile = _data!['profiles'] as Map<String, dynamic>?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _personRow(context, profile),
            const SizedBox(height: 10),
            Text(l10n.youJoinedGroup,
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryLight.withOpacity(0.9))),
            const SizedBox(height: 10),
            _row(context, 'Time',
                _formatDate(DateTime.parse(_data!['joined_at'] as String? ??
                    n.createdAt.toIso8601String()))),
          ],
        );

      default:
        return Text(n.body);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.primaryDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          if (_group != null)
            Text(_group!.name,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryLight)),
          const SizedBox(height: 4),
          _buildContent(context),
          const SizedBox(height: 20),
          if (_group != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            GroupDetailScreen(group: _group!)),
                  );
                },
                child: Text('View in ${_group!.name}'),
              ),
            ),
        ],
      ),
    );
  }
}