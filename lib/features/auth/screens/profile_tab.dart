import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitly/features/settings/controllers/locale_controller.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/screens/login_screen.dart';
import '../../reports/screens/reports_screen.dart';
import '../../security/controllers/app_lock_controller.dart';
import '../../security/screens/set_pin_screen.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final user = ref.watch(currentUserProvider);

    final fullName =
        user?.userMetadata?['full_name'] as String? ?? 'Splitly User';
    final email = user?.email ?? '';
    final avatarLetter =
    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S';

    final textColor =
    dark ? AppColors.primaryTint : AppColors.primaryDark;
    final cardBg = dark ? AppColors.primaryDark : Colors.white;
    final cardBorder = dark
        ? AppColors.primary.withOpacity(0.2)
        : AppColors.primaryTint;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.profile,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryTint)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 32),

            // ── Avatar ────────────────────────────────────────────────
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(avatarLetter,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w500,
                        color: Colors.white)),
              ),
            ),

            const SizedBox(height: 16),

            Text(fullName,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: textColor)),
            const SizedBox(height: 4),
            Text(email,
                style: TextStyle(
                    fontSize: 14, color: AppColors.primary)),

            const SizedBox(height: 32),

            // ── Section 1 — Main settings ─────────────────────────────
            _SectionCard(
              cardBg: cardBg,
              cardBorder: cardBorder,
              children: [
                _ProfileTile(
                  icon: Icons.person_outlined,
                  label: l10n.editProfile,
                  onTap: () {},
                ),
                _Divider(),

                // ✅ Reports tile
                _ProfileTile(
                  icon: Icons.bar_chart_rounded,
                  label: l10n.spendingReports,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReportsScreen(),
                    ),
                  ),
                ),
                _Divider(),

                _ProfileTile(
                  icon: Icons.notifications_outlined,
                  label: l10n.notifications,
                  onTap: () {},
                ),
                _Divider(),
                _ProfileTile(
                  icon: isDark(context)
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  label: isDark(context) ? l10n.lightMode : l10n.darkMode,
                  trailing: Text(l10n.system,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryLight)),
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Section 2 — App settings ──────────────────────────────
            _SectionCard(
              cardBg: cardBg,
              cardBorder: cardBorder,
              children: [
                _ProfileTile(
                  icon: Icons.language_rounded,
                  label: l10n.language,
                  trailing: Text(
                    ref.watch(localeControllerProvider).languageCode == 'ur' ? 'اردو' : 'English',
                    style: TextStyle(fontSize: 12, color: AppColors.primaryLight),
                  ),
                  onTap: () => _showLanguageSheet(context, ref),
                ),
                _Divider(),
                _ProfileTile(
                  icon: Icons.lock_outline_rounded,
                  label: l10n.appLock,
                  onTap: () => _showAppLockSheet(context, ref),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Section 3 — Sign out ──────────────────────────────────
            _SectionCard(
              cardBg: cardBg,
              cardBorder: cardBorder,
              children: [
                _ProfileTile(
                  icon: Icons.logout_rounded,
                  label: l10n.signOut,
                  labelColor: AppColors.danger,
                  iconColor: AppColors.danger,
                  onTap: () => _confirmSignOut(context, ref),
                ),
              ],
            ),

            const SizedBox(height: 40),

            Text(
              l10n.splitlyFooter,
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryLight.withOpacity(0.5)),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final currentLocale = ref.read(localeControllerProvider).languageCode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: dark ? AppColors.primaryDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Text(l10n.language,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600,
                    color: dark ? AppColors.primaryTint : AppColors.primaryDark)),
            const SizedBox(height: 20),

            _LangTile(
              label: 'English',
              subtitle: 'English',
              selected: currentLocale == 'en',
              dark: dark,
              onTap: () {
                ref.read(localeControllerProvider.notifier).setLocale('en');
                Navigator.pop(sheetContext);
              },
            ),
            const SizedBox(height: 10),
            _LangTile(
              label: 'اردو',
              subtitle: 'Urdu',
              selected: currentLocale == 'ur',
              dark: dark,
              onTap: () {
                ref.read(localeControllerProvider.notifier).setLocale('ur');
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(
      BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.signOut),
        content: Text(l10n.signOutConfirmDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.danger),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(authControllerProvider.notifier).signOut();
      } catch (_) {}
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
      }
    }
  }
}

void _showAppLockSheet(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = ref.read(appLockControllerProvider.notifier);
  final isEnabled = await controller.isLockEnabled();
  final canBiometric = await controller.canUseBiometrics();
  final biometricOn = await controller.isBiometricEnabled();

  if (!context.mounted) return;
  final dark = isDark(context);
  final sheetBg = dark ? AppColors.primaryDark : Colors.white;
  final textColor = dark ? AppColors.primaryTint : AppColors.primaryDark;
  final borderColor = dark ? AppColors.primary.withOpacity(0.3) : AppColors.primaryTint;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        bool localBiometricOn = biometricOn;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Icon + heading
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_outline_rounded,
                        color: AppColors.primary, size: 26),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.appLock,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600, color: textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  isEnabled
                      ? l10n.protectSplitly
                      : l10n.addExtraLayer,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.primary),
                ),
                const SizedBox(height: 24),

                if (!isEnabled)
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SetPinScreen()),
                      );
                    },
                    icon: const Icon(Icons.lock_outline_rounded, size: 18),
                    label: Text(l10n.enablePinLock),
                  )
                else ...[
                  if (canBiometric)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l10n.useBiometricUnlock,
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
                        ),
                        subtitle: Text(
                          l10n.unlockWithFingerprint,
                          style: TextStyle(fontSize: 12, color: AppColors.primaryLight),
                        ),
                        value: localBiometricOn,
                        activeColor: AppColors.primary,
                        onChanged: (val) async {
                          await controller.setBiometricEnabled(val);
                          setSheetState(() => localBiometricOn = val);
                        },
                      ),
                    ),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _confirmDisableAppLock(context, ref);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(color: AppColors.danger.withOpacity(0.4)),
                    ),
                    icon: const Icon(Icons.lock_open_rounded, size: 18),
                    label: Text(l10n.disableAppLock),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

void _confirmDisableAppLock(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context)!;
  final dark = isDark(context);
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: dark ? AppColors.primaryDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        l10n.disableAppLockTitle,
        style: TextStyle(color: dark ? AppColors.primaryTint : AppColors.primaryDark),
      ),
      content: Text(
        l10n.disableAppLockDesc,
        style: TextStyle(
          color: dark
              ? AppColors.primaryTint.withOpacity(0.8)
              : AppColors.primaryDark.withOpacity(0.7),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.cancel, style: TextStyle(color: AppColors.primary)),
        ),
        TextButton(
          onPressed: () async {
            await ref.read(appLockControllerProvider.notifier).disableLock();
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (context.mounted) showSuccessSnack(context, l10n.disableAppLock);
          },
          child: Text(l10n.disable, style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
}

// ── Section card ──────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  final Color cardBg;
  final Color cardBorder;

  const _SectionCard({
    required this.children,
    required this.cardBg,
    required this.cardBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

// ── Profile tile ──────────────────────────────────────────────────────────────
class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;
  final Color? iconColor;
  final Widget? trailing;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final defaultTextColor =
    dark ? AppColors.primaryTint : AppColors.primaryDark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon,
                size: 20, color: iconColor ?? AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: labelColor ?? defaultTextColor)),
            ),
            trailing ??
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppColors.primaryLight),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 50),
      child: Divider(
          height: 0.5,
          thickness: 0.5,
          color: AppColors.primaryTint),
    );
  }
}

class _LangTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  const _LangTile({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? AppColors.primaryTint : AppColors.primaryDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.primaryTint,
            width: selected ? 2 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.primaryLight)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}