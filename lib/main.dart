import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase/supabase_config.dart';
import 'config/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/reset_password_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/home_screen.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/balances/controllers/balances_controller.dart';
import 'features/chat/controllers/chat_controller.dart';
import 'features/expenses/controllers/expenses_controller.dart';
import 'features/expenses/screens/expense_history_screen.dart';
import 'features/groups/controllers/groups_controller.dart';
import 'features/notifications/controllers/fcm_service.dart';
import 'features/notifications/controllers/notification_router.dart';
import 'features/notifications/controllers/notifications_controller.dart';
import 'firebase_options.dart';
import 'features/security/controllers/app_lock_controller.dart';
import 'features/security/screens/unlock_screen.dart';
import 'features/settings/controllers/locale_controller.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'l10n/app_localizations.dart';

// ── Global navigator key ──────────────────────────────────────────────────────
// Attached to MaterialApp so ALL navigation uses the same stack
// This fixes the back button closing the app issue
final _navigatorKey = GlobalKey<NavigatorState>();

// Tapped notifications open their screen — turned on once Home is showing
// (a tap from before that waits in FCMService until then).
void _enableNotificationTaps(ProviderContainer container) {
  FCMService.setOpenHandler((data) {
    // Next event-loop turn, so a Home route pushed just now is in place
    Future(() {
      final nav = _navigatorKey.currentState;
      if (nav == null) return;
      openNotificationTarget(nav, container,
          type: data['type'] as String?,
          groupId: data['group_id'] as String?,
          entityId: data['entity_id'] as String?);
    });
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before runApp, so it gets the back button before the Navigator does
  WidgetsBinding.instance.addObserver(AppLockBackGuard());
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Crash reporting (Firebase Crashlytics) ─────────────────────────────────
  // Off in debug builds so testing doesn't fill the dashboard. Reports
  // contain the stack trace + device/OS/app version — no names or messages.
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);
  // Errors inside Flutter widgets/frameworks
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  // Everything else (async errors that nothing caught)
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await SupabaseConfig.initialize();
  await FCMService().initialize();
  runApp(const ProviderScope(child: SplitlyApp()));
}

// ✅ Converted to ConsumerWidget so it can watch the locale provider
class SplitlyApp extends ConsumerWidget {
  const SplitlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);

    return MaterialApp(
      title: 'Splitly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      // ✅ Key fix — navigatorKey on MaterialApp means all Navigator calls
      // use the same stack, so back button works correctly everywhere
      navigatorKey: _navigatorKey,

      // ✅ Language support (English / Urdu)
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ur'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // App lock covers every screen (see _AppLockOverlay)
      builder: (context, child) =>
          _AppLockOverlay(child: child ?? const SizedBox.shrink()),

      home: const AuthGate(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP LOCK OVERLAY
// ─────────────────────────────────────────────────────────────────────────────
// Sits in MaterialApp.builder, ABOVE the Navigator, so the unlock screen
// covers every route (chat, group details, sheets, dialogs). The screens
// underneath stay alive, so nothing typed is lost. Locks on cold start, and
// after the app was in the background for kLockGracePeriod — but not when
// the app opened its own camera/picker/share sheet (runWithoutLock).
class _AppLockOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const _AppLockOverlay({required this.child});

  @override
  ConsumerState<_AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends ConsumerState<_AppLockOverlay>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(appLockControllerProvider.notifier).lockIfEnabled();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(appLockControllerProvider.notifier);
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      controller.onBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      controller.onResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = ref.watch(appLockControllerProvider);
    return Stack(
      children: [
        // Hidden app: no taps, no keyboard focus, nothing read aloud
        ExcludeSemantics(
          excluding: isLocked,
          child: ExcludeFocus(
            excluding: isLocked,
            child: IgnorePointer(ignoring: isLocked, child: widget.child),
          ),
        ),
        if (isLocked) const Positioned.fill(child: UnlockScreen()),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH GATE
// ─────────────────────────────────────────────────────────────────────────────
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isPasswordRecovery = false;

  // The root ProviderContainer. NOT a widget `ref`: this widget's route is
  // removed after the first navigation, but the auth listener below keeps
  // running for the whole app lifetime — a widget ref would throw then.
  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);

    // A push arrived while the app is open → reload just what it is about
    FCMService.onForegroundData = _onPushData;

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      _handleAuthEvent(event);
    });
  }

  void _navigate(Widget screen) {
    // Use MaterialApp's navigatorKey — same stack as all other navigation
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
          (_) => false,
    );
  }

  void _handleAuthEvent(AuthChangeEvent event) {
    switch (event) {
      case AuthChangeEvent.passwordRecovery:
        _isPasswordRecovery = true;
        _navigate(const ResetPasswordScreen());
        break;

      // tokenRefreshed is NOT handled here on purpose: Supabase renews the
      // token about once an hour, and rebuilding the stack on it kicked the
      // user out of whatever screen they were on (and re-triggered app lock).
      case AuthChangeEvent.signedIn:
        if (_isPasswordRecovery) return;
        // Throw away anything cached from a previous user before Home builds
        _resetUserData();
        FCMService().saveTokenToSupabase();
        // No lock here: the user has just signed in with their password
        _navigate(const HomeScreen());
        _enableNotificationTaps(_container);
        break;

      case AuthChangeEvent.userUpdated:
      // Supabase fires this event on ANY auth.updateUser() call — both
      // the password-recovery flow (set new password) AND regular
      // profile edits (e.g. changing full_name). Only force a re-login
      // when it's actually the recovery flow finishing; otherwise this
      // would log the user out every time they edit their profile.
        if (_isPasswordRecovery) {
          _isPasswordRecovery = false;
          _navigate(const LoginScreen());
        }
        break;

      case AuthChangeEvent.signedOut:
        _isPasswordRecovery = false;
        FCMService.setOpenHandler(null);
        _navigate(const LoginScreen());
        _resetUserData();
        FCMService().deleteDeviceToken();
        break;

      default:
        break;
    }
  }

  void _onPushData(Map<String, dynamic> data) {
    final groupId = data['group_id'] as String? ?? '';
    _container.invalidate(notificationsProvider);
    switch (data['type']) {
      case 'message':
        _container.invalidate(unreadCountsProvider);
        break;
      case 'expense':
      case 'settlement':
        _container.invalidate(myDebtsProvider);
        if (groupId.isNotEmpty) {
          _container.invalidate(expensesProvider(groupId));
          _container.invalidate(settlementsProvider(groupId));
        }
        break;
      case 'member_joined':
        _container.invalidate(groupsProvider);
        if (groupId.isNotEmpty) {
          _container.invalidate(groupMembersProvider(groupId));
        }
        break;
    }
  }

  // Clears every provider that holds the signed-in user's data, so the next
  // user on this device never sees the previous user's groups, chats, etc.
  // Families (expensesProvider, messagesProvider, ...) are invalidated as a
  // whole — every group's instance at once. Chat instances close their
  // realtime channel in onDispose.
  void _resetUserData() {
    // Auth / profile
    _container.invalidate(currentUserProvider);
    _container.invalidate(myProfileProvider);

    // Groups
    _container.invalidate(groupsProvider);
    _container.invalidate(unreadCountsProvider);
    _container.invalidate(archivedGroupsProvider);
    _container.invalidate(groupDetailProvider);
    _container.invalidate(groupMembersProvider);

    // Expenses + balances
    _container.invalidate(expensesProvider);
    _container.invalidate(myDebtsProvider);
    _container.invalidate(settlementsProvider);
    _container.invalidate(groupBalanceSummaryProvider);

    // Chat
    _container.invalidate(messagesProvider);
    _container.invalidate(typingUsersProvider);

    // Notifications
    _container.invalidate(notificationsProvider);
    _container.invalidate(unreadNotificationCountProvider);
    _container.invalidate(notificationPrefsProvider);

    // UI state — next user starts on the Groups tab with no filters
    _container.invalidate(bottomNavIndexProvider);
    _container.invalidate(selectedCategoryFilterProvider);
    _container.invalidate(selectedDateFilterProvider);
    _container.invalidate(customDateRangeProvider);
    _container.invalidate(searchQueryProvider);
  }

  @override
  Widget build(BuildContext context) {
    // AuthGate just shows the initial screen
    // All auth-driven navigation happens via _navigatorKey above
    return const _InitialScreen();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INITIAL SCREEN — shows splash for 2 seconds then routes by session/onboarding
// ─────────────────────────────────────────────────────────────────────────────
class _InitialScreen extends StatefulWidget {
  const _InitialScreen();

  @override
  State<_InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<_InitialScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final session = Supabase.instance.client.auth.currentSession;
      final seenOnboarding = await hasSeenOnboarding();

      Widget destination;
      if (session != null) {
        // Already logged in → skip onboarding, go straight to home
        // (_AppLockOverlay has already locked if app lock is on)
        destination = const HomeScreen();
      } else if (!seenOnboarding) {
        // First time ever opening the app → show onboarding slides
        destination = const OnboardingScreen();
      } else {
        // Seen onboarding before but not logged in → go to login
        destination = const LoginScreen();
      }

      if (!mounted) return;
      final container = ProviderScope.containerOf(context, listen: false);
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
            (_) => false,
      );
      if (session != null) _enableNotificationTaps(container);
    });
  }

  @override
  Widget build(BuildContext context) => const SplashScreen();
}