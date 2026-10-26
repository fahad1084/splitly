import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/notifications_controller.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  Map<String, bool>? _prefs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final prefsAsync = ref.watch(notificationPrefsProvider);

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
        title: Text(l10n.notificationSettings,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryTint)),
      ),
      body: prefsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Text(l10n.somethingWentWrong,
              style: const TextStyle(color: AppColors.danger)),
        ),
        data: (loaded) {
          _prefs ??= Map<String, bool>.from(loaded);
          final prefs = _prefs!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.notificationSettingsDesc,
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryLight.withOpacity(0.8))),
              const SizedBox(height: 20),
              _PrefTile(
                icon: Icons.chat_bubble_outline_rounded,
                label: l10n.notifyNewMessages,
                value: prefs['notify_messages'] ?? true,
                dark: dark,
                onChanged: (v) {
                  setState(() => prefs['notify_messages'] = v);
                  NotificationsController.updatePreference(
                      'notify_messages', v);
                },
              ),
              const SizedBox(height: 10),
              _PrefTile(
                icon: Icons.receipt_long_rounded,
                label: l10n.notifyNewExpenses,
                value: prefs['notify_expenses'] ?? true,
                dark: dark,
                onChanged: (v) {
                  setState(() => prefs['notify_expenses'] = v);
                  NotificationsController.updatePreference(
                      'notify_expenses', v);
                },
              ),
              const SizedBox(height: 10),
              _PrefTile(
                icon: Icons.handshake_outlined,
                label: l10n.notifySettlements,
                value: prefs['notify_settlements'] ?? true,
                dark: dark,
                onChanged: (v) {
                  setState(() => prefs['notify_settlements'] = v);
                  NotificationsController.updatePreference(
                      'notify_settlements', v);
                },
              ),
              const SizedBox(height: 10),
              _PrefTile(
                icon: Icons.person_add_alt_1_rounded,
                label: l10n.notifyNewMembers,
                value: prefs['notify_members'] ?? true,
                dark: dark,
                onChanged: (v) {
                  setState(() => prefs['notify_members'] = v);
                  NotificationsController.updatePreference(
                      'notify_members', v);
                },
              ),
              const SizedBox(height: 10),
              _PrefTile(
                icon: Icons.alarm_rounded,
                label: l10n.notifyDebtReminders,
                value: prefs['notify_debt_reminders'] ?? true,
                dark: dark,
                onChanged: (v) {
                  setState(() => prefs['notify_debt_reminders'] = v);
                  NotificationsController.updatePreference(
                      'notify_debt_reminders', v);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final bool dark;
  final ValueChanged<bool> onChanged;

  const _PrefTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.dark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? AppColors.primaryDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
          dark ? AppColors.primary.withOpacity(0.2) : AppColors.primaryTint,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    color: dark
                        ? AppColors.primaryTint
                        : AppColors.primaryDark)),
          ),
          Switch(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}