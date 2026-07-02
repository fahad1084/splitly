import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

class SplitlyApp extends StatelessWidget {
  const SplitlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Splitly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      // ✅ Key fix — navigatorKey on MaterialApp means all Navigator calls
      // use the same stack, so back button works correctly everywhere
      navigatorKey: _navigatorKey,
      home: const AuthGate(),
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
        _navigate(const HomeScreen());
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
// INITIAL SCREEN — shows splash for 2 seconds then routes by session
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

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      final session = Supabase.instance.client.auth.currentSession;
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
          session != null ? const HomeScreen() : const LoginScreen(),
        ),
            (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SplashScreen();
}
