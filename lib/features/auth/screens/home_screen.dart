import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../features/groups/screens/groups_tab.dart';
import '../../balances/screens/balances_tab.dart';
import '../../../l10n/app_localizations.dart';
import '../../balances/controllers/balances_controller.dart';
import '../../expenses/controllers/expenses_controller.dart';
import '../../groups/controllers/groups_controller.dart';
import '../../notifications/controllers/notifications_controller.dart';
import 'profile_tab.dart';

// ── Bottom nav index provider ─────────────────────────────────────────────────
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  // Coming back after at least this long reloads balances, badges and
  // notifications — so nobody needs to pull to refresh.
  static const _refreshAfter = Duration(seconds: 10);
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _pausedAt;
      _pausedAt = null;
      if (since == null || DateTime.now().difference(since) < _refreshAfter) {
        return;
      }
      ref.invalidate(myDebtsProvider);
      ref.invalidate(unreadCountsProvider);
      ref.invalidate(notificationsProvider);
      // Families: only the groups that are open right now reload
      ref.invalidate(expensesProvider);
      ref.invalidate(settlementsProvider);
    }
  }

  static const _tabs = [
    GroupsTab(),
    BalancesTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final dark = isDark(context);

    // Nav bar colors
    final navBg =
    dark ? AppColors.primaryDark : Colors.white;
    const navSelected = AppColors.primary;
    final navUnselected =
    dark ? AppColors.primaryLight.withValues(alpha: 0.5) : AppColors.primaryLight;
    final indicatorColor =
    dark ? AppColors.primary.withValues(alpha: 0.2) : AppColors.primaryTint;

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
            selectedIcon: const Icon(Icons.group_rounded, color: navSelected),
            label: l10n.groups,
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined,
                color: navUnselected),
            selectedIcon: const Icon(Icons.account_balance_wallet_rounded,
                color: navSelected),
            label: l10n.balances,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined, color: navUnselected),
            selectedIcon: const Icon(Icons.person_rounded, color: navSelected),
            label: l10n.profile,
          ),
        ],
      ),
    );
  }
}