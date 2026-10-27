import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/notifications_controller.dart';
import '../controllers/notification_router.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // notificationsProvider is a plain FutureProvider — it caches its
    // result and won't auto-refetch just because this screen reopened.
    // Force a fresh fetch every time so newly-arrived notifications show.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(notificationsProvider);
    });
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'message':
        return Icons.chat_bubble_outline_rounded;
      case 'expense':
        return Icons.receipt_long_rounded;
      case 'settlement':
        return Icons.handshake_outlined;
      case 'member_joined':
        return Icons.person_add_alt_1_rounded;
      case 'debt_reminder':
        return Icons.alarm_rounded;
      case 'recurring_skipped':
        return Icons.event_busy_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.toLocal().day}/${dt.toLocal().month}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final notificationsAsync = ref.watch(notificationsProvider);
    final userId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.primaryTint, size: 16),
          ),
        ),
        title: Text(l10n.notifications,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryTint)),
        actions: [
          if (userId != null)
            TextButton(
              onPressed: () async {
                await NotificationsController.markAllAsRead(userId);
                ref.invalidate(notificationsProvider);
              },
              child: Text(l10n.markAllRead,
                  style: const TextStyle(
                      color: AppColors.primaryTint, fontSize: 12)),
            ),
        ],
      ),
      body: notificationsAsync.when(
        skipError: true, // keep the last data if a reload fails
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => ErrorRetry(
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined,
                        size: 56,
                        color: AppColors.primaryLight.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text(l10n.noNotificationsYet,
                        style: TextStyle(
                            color: AppColors.mutedText(context)
                                .withOpacity(0.8))),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n = notifications[i];
                return GestureDetector(
                  onTap: () async {
                    if (n.isUnread) {
                      await NotificationsController.markAsRead(n.id);
                      ref.invalidate(notificationsProvider);
                    }
                    if (!context.mounted) return;
                    await openNotificationTarget(
                      Navigator.of(context),
                      ProviderScope.containerOf(context, listen: false),
                      type: n.type,
                      groupId: n.groupId,
                      entityId: n.entityId,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.isUnread
                          ? (dark
                          ? AppColors.primary.withOpacity(0.15)
                          : AppColors.primaryTint)
                          : (dark ? AppColors.primaryDark : Colors.white),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: dark
                            ? AppColors.primary.withOpacity(0.2)
                            : AppColors.primaryTint,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_iconFor(n.type),
                              color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(n.title,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: dark
                                          ? AppColors.primaryTint
                                          : AppColors.primaryDark)),
                              const SizedBox(height: 2),
                              Text(n.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.mutedText(context)
                                          .withOpacity(0.9))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_timeAgo(n.createdAt),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedText(context)
                                        .withOpacity(0.6))),
                            if (n.isUnread) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}