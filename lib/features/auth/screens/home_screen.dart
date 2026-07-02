import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../features/groups/screens/groups_tab.dart';
import '../../balances/screens/balances_tab.dart';
import '../../../l10n/app_localizations.dart';
import 'profile_tab.dart';

// ── Bottom nav index provider ─────────────────────────────────────────────────
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _tabs = [
    GroupsTab(),
    BalancesTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final dark = isDark(context);

    // Nav bar colors
    final navBg =
    dark ? AppColors.primaryDark : Colors.white;
    final navSelected = AppColors.primary;
    final navUnselected =
    dark ? AppColors.primaryLight.withOpacity(0.5) : AppColors.primaryLight;
    final indicatorColor =
    dark ? AppColors.primary.withOpacity(0.2) : AppColors.primaryTint;

    return Scaffold(
      // IndexedStack keeps all tabs alive — no reload on tab switch
      body: IndexedStack(
        index: currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) =>
        ref.read(bottomNavIndexProvider.notifier).state = index,
        backgroundColor: navBg,
        indicatorColor: indicatorColor,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.group_outlined, color: navUnselected),
            selectedIcon: Icon(Icons.group_rounded, color: navSelected),
            label: l10n.groups,
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined,
                color: navUnselected),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded,
                color: navSelected),
            label: l10n.balances,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined, color: navUnselected),
            selectedIcon: Icon(Icons.person_rounded, color: navSelected),
            label: l10n.profile,
          ),
        ],
      ),
    );
  }
}