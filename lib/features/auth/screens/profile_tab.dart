import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/screens/login_screen.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = isDark(context);
    final user = ref.watch(currentUserProvider);

    final fullName =
        user?.userMetadata?['full_name'] as String? ?? 'Splitly User';
    final email = user?.email ?? '';
    final avatarLetter = fullName.isNotEmpty
        ? fullName[0].toUpperCase()
        : 'S';

    final textColor =
    dark ? AppColors.primaryTint : AppColors.primaryDark;
    final cardBg = dark ? AppColors.primaryDark : Colors.white;
    final cardBorder =
    dark ? AppColors.primary.withOpacity(0.2) : AppColors.primaryTint;
    final subColor = AppColors.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryTint,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 32),

            // ── Avatar ───────────────────────────────────────────────────
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  avatarLetter,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Name ─────────────────────────────────────────────────────
            Text(
              fullName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: TextStyle(fontSize: 14, color: subColor),
            ),

            const SizedBox(height: 32),

            // ── Settings section ─────────────────────────────────────────
            _SectionCard(
              cardBg: cardBg,
              cardBorder: cardBorder,
              children: [
                _ProfileTile(
                  icon: Icons.person_outlined,
                  label: 'Edit Profile',
                  onTap: () {
                    // TODO: edit profile screen
                  },
                ),
                _Divider(),
                _ProfileTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  onTap: () {
                    // TODO: notifications settings
                  },
                ),
                _Divider(),
                _ProfileTile(
                  icon: isDark(context)
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  label: isDark(context) ? 'Light Mode' : 'Dark Mode',
                  trailing: Text(
                    'System',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.primaryLight),
                  ),
                  onTap: () {
                    // Theme follows system — Option B toggle can be added later
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            _SectionCard(
              cardBg: cardBg,
              cardBorder: cardBorder,
              children: [
                _ProfileTile(
                  icon: Icons.language_outlined,
                  label: 'Language',
                  trailing: Text(
                    'English',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.primaryLight),
                  ),
                  onTap: () {
                    // TODO: language screen
                  },
                ),
                _Divider(),
                _ProfileTile(
                  icon: Icons.lock_outlined,
                  label: 'App Lock / PIN',
                  onTap: () {
                    // TODO: app lock screen
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Sign Out ─────────────────────────────────────────────────
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

            // ── App version ──────────────────────────────────────────────
            Text(
              'Splitly v1.0.0 · Your Circle. Your Hisaab.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.primaryLight.withOpacity(0.5),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
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
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Sign out from Supabase
        await ref.read(authControllerProvider.notifier).signOut();
      } catch (_) {
        // Even if signOut throws, still navigate to login
      }

      // Navigate manually as a guaranteed fallback
      // This runs regardless of whether AuthGate catches the event
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
      }
    }
  }
}

// ── Reusable card wrapper ─────────────────────────────────────────────────────
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

// ── Profile list tile ─────────────────────────────────────────────────────────
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? AppColors.primary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: labelColor ?? defaultTextColor,
                ),
              ),
            ),
            trailing ??
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.primaryLight,
                ),
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
        color: AppColors.primaryTint,
      ),
    );
  }
}