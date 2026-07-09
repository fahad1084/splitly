import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'features/notifications/controllers/fcm_service.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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

      home: const AuthGate(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP LOCK WRAPPER
// ─────────────────────────────────────────────────────────────────────────────
// Wraps HomeScreen. Checks PIN lock on cold start and re-locks whenever
// the app goes to background (paused lifecycle state).
class _AppLockWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const _AppLockWrapper({required this.child});

  @override
  ConsumerState<_AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends ConsumerState<_AppLockWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockOnStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkLockOnStart() async {
    final enabled =
    await ref.read(appLockControllerProvider.notifier).isLockEnabled();
    if (enabled && mounted) {
      ref.read(appLockControllerProvider.notifier).lock();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _checkLockOnStart(); // re-lock when app goes to background
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = ref.watch(appLockControllerProvider);
    return isLocked ? const UnlockScreen() : widget.child;
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

  @override
  void initState() {
    super.initState();

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

      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
        if (_isPasswordRecovery) return;
        // ✅ Wrapped with app lock check
        _navigate(const _AppLockWrapper(child: HomeScreen()));
        break;

      case AuthChangeEvent.userUpdated:
        _isPasswordRecovery = false;
        _navigate(const LoginScreen());
        break;

      case AuthChangeEvent.signedOut:
        _isPasswordRecovery = false;
        _navigate(const LoginScreen());
        break;

      default:
        break;
    }
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
        // Already logged in → skip onboarding, go straight to home (with lock check)
        destination = const _AppLockWrapper(child: HomeScreen());
      } else if (!seenOnboarding) {
        // First time ever opening the app → show onboarding slides
        destination = const OnboardingScreen();
      } else {
        // Seen onboarding before but not logged in → go to login
        destination = const LoginScreen();
      }

      if (!mounted) return;
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
            (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SplashScreen();
}