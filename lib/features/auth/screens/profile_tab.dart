import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/screens/login_screen.dart';
import '../../reports/screens/reports_screen.dart';
import '../../security/controllers/app_lock_controller.dart';
import '../../security/screens/set_pin_screen.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        title: const Text('Profile',
            style: TextStyle(
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
                  label: 'Edit Profile',
                  onTap: () {},
                ),
                _Divider(),

                // ✅ Reports tile
                _ProfileTile(
                  icon: Icons.bar_chart_rounded,
                  label: 'Spending Reports',
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
                  label: 'Notifications',
                  onTap: () {},
                ),
                _Divider(),
                _ProfileTile(
                  icon: isDark(context)
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  label: isDark(context) ? 'Light Mode' : 'Dark Mode',
                  trailing: Text('System',
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
                  icon: Icons.language_outlined,
                  label: 'Language',
                  trailing: Text('English',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryLight)),
                  onTap: () {},
                ),
                _Divider(),
                _ProfileTile(
                  icon: Icons.lock_outline_rounded,
                  label: 'App Lock / PIN',
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
                  label: 'Sign Out',
                  labelColor: AppColors.danger,
                  iconColor: AppColors.danger,
                  onTap: () => _confirmSignOut(context, ref),
                ),
              ],
            ),

            const SizedBox(height: 40),

            Text(
              'Splitly v1.0.0 · Your Circle. Your Hisaab.',
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

  Future<void> _confirmSignOut(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.danger),
            child: const Text('Sign Out'),
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
  final controller = ref.read(appLockControllerProvider.notifier);
  final isEnabled = await controller.isLockEnabled();
  final canBiometric = await controller.canUseBiometrics();
  final biometricOn = await controller.isBiometricEnabled();

  if (!context.mounted) return;
  final dark = isDark(context);

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
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Text('App Lock',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600,
                  color: dark ? AppColors.primaryTint : AppColors.primaryDark)),
          const SizedBox(height: 20),

          if (!isEnabled)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SetPinScreen()));
              },
              icon: const Icon(Icons.lock_outline_rounded),
              label: const Text('Enable PIN Lock'),
            )
          else ...[
            if (canBiometric)
              SwitchListTile(
                title: const Text('Use Biometric Unlock'),
                value: biometricOn,
                activeColor: AppColors.primary,
                onChanged: (val) async {
                  await controller.setBiometricEnabled(val);
                  Navigator.pop(sheetContext);
                },
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await controller.disableLock();
                if (context.mounted) {
                  Navigator.pop(sheetContext);
                  showSuccessSnack(context, 'App Lock disabled');
                }
              },
              icon: Icon(Icons.lock_open_rounded, color: AppColors.danger),
              label: Text('Disable App Lock', style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ],
      ),
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