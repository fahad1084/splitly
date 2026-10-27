import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/groups_controller.dart';
import '../../../core/utils/app_errors.dart';

class ArchivedGroupsScreen extends ConsumerWidget {
  const ArchivedGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final archivedAsync = ref.watch(archivedGroupsProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: LabeledTap(
          label: AppLocalizations.of(context)!.back,
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.primaryTint, size: 16),
          ),
        ),
        title: Text(l10n.archivedGroups,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryTint)),
      ),
      body: archivedAsync.when(
        skipError: true, // keep the last data if a reload fails
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => ErrorRetry(
          onRetry: () => ref.invalidate(archivedGroupsProvider),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.archive_outlined,
                        size: 56,
                        color: AppColors.primaryLight.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text(l10n.noArchivedGroups,
                        style: TextStyle(
                            color: AppColors.mutedText(context)
                                .withValues(alpha: 0.8))),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final group = groups[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: dark ? AppColors.primaryDark : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: dark
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : AppColors.primaryTint,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.archive_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        group.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: dark
                              ? AppColors.primaryTint
                              : AppColors.primaryDark,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () async {
                            await ref
                                .read(groupsProvider.notifier)
                                .unarchiveGroup(group.id);
                            ref.invalidate(archivedGroupsProvider);
                            if (context.mounted) {
                              showSuccessSnack(
                                  context, l10n.groupUnarchived);
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                          ),
                          child: Text(l10n.unarchive,
                              style: const TextStyle(
                                  color: AppColors.primary, fontSize: 12)),
                        ),
                        if (group.createdBy == currentUserId)
                          TextButton(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: Text(l10n.deleteGroupTitle),
                                  content:
                                  Text(l10n.deleteGroupWarning(group.name)),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: Text(l10n.cancel),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      style: TextButton.styleFrom(
                                          foregroundColor: AppColors.danger),
                                      child: Text(l10n.deletePermanently),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true || !context.mounted) {
                                return;
                              }
                              final error = await ref
                                  .read(groupsProvider.notifier)
                                  .deleteGroupPermanently(group.id);
                              if (!context.mounted) return;
                              if (error != null) {
                                showErrorSnack(context, friendlyError(AppLocalizations.of(context)!, error));
                              } else {
                                ref.invalidate(archivedGroupsProvider);
                                showSuccessSnack(
                                    context, l10n.groupDeleted);
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 32),
                            ),
                            child: Text(l10n.deletePermanently,
                                style: TextStyle(
                                    color: AppColors.dangerText(context), fontSize: 12)),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}