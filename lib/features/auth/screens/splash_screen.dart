import 'package:flutter/material.dart';
import 'package:splitly/features/auth/screens/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _slideAnim = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2200), _redirect);
  }

  Future<void> _redirect() async {
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    await _ctrl.reverse();
    if (!mounted) return;
    final destination = session != null
        ? const HomeScreen()   // ← was LoginScreen
        : const LoginScreen();
    Navigator.pushReplacement(context, _fadeRoute(destination));
  }

  PageRoute _fadeRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 500),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);

    // ── Pick correct asset based on system theme ──────────────────────────
    // Light mode → assets/images/splash_light.png
    // Dark mode  → assets/images/splash_dark.png
    final splashAsset = dark
        ? 'assets/images/splash_dark.png'
        : 'assets/images/splash_light.png';

    // Background color matches the asset's background
    final bgColor = dark ? AppColors.darkBg : AppColors.lightBg;

    // Text colors match the asset's theme
    final nameColor = dark ? AppColors.primaryTint : AppColors.primaryDark;
    final taglineColor = dark ? AppColors.accent : AppColors.accentDark;
    final spinnerColor = dark
        ? AppColors.accent.withOpacity(0.6)
        : AppColors.primary.withOpacity(0.6);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => FadeTransition(
            opacity: _fadeAnim,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Splash asset (your branded image) ──────────────────
                  // Uses your actual splash asset from assets/images/
                  // Falls back to the custom S-Blob painter if asset not found
                  Transform.translate(
                    offset: Offset(0, _slideAnim.value),
                    child: Image.asset(
                      splashAsset,
                      width: 180,
                      height: 180,
                      errorBuilder: (_, __, ___) {
                        // Fallback: S-Blob painter if image not found
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 96,
                              height: 96,
                              child: CustomPaint(
                                painter: SBlobPainter(
                                  tealColor: AppColors.primary,
                                  goldColor: AppColors.accent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Splitly',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w500,
                                color: nameColor,
                                letterSpacing: -1.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your Circle. Your Hisaab.',
                              style: TextStyle(
                                fontSize: 14,
                                color: taglineColor,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 56),

                  // ── Loading spinner ────────────────────────────────────
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: spinnerColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}