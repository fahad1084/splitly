import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/auth_controller.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'package:flutter/services.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Email sign in ─────────────────────────────────────────────────────────

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final error = await ref.read(authControllerProvider.notifier).signIn(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      showErrorSnack(context, error);
    } else {
      // ✅ THIS triggers the "Save password to Google?" popup on Android
      // Must be called after successful login, before navigation
      TextInput.finishAutofillContext(shouldSave: true);

      // AuthGate handles navigation automatically via onAuthStateChange
    }
  }

  // ── Google sign in ────────────────────────────────────────────────────────
  Future<void> _googleSignIn() async {
    setState(() => _isGoogleLoading = true);
    final error =
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    if (error != null) showErrorSnack(context, error);
    // ✅ No navigation here — AuthGate handles it automatically on signedIn event
  }
  void _goToSignUp() => Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => const SignUpScreen(),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
            begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(
            parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 350),
    ),
  );

  void _goToForgotPassword() => Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => const ForgotPasswordScreen(),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
            begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(
            parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 350),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final headingColor =
    dark ? AppColors.primaryTint : AppColors.primaryDark;
    final dividerColor =
    dark ? AppColors.primaryDark : AppColors.primaryTint;
    final linkMutedColor = dark
        ? AppColors.primaryTint.withOpacity(0.6)
        : AppColors.primaryDark.withOpacity(0.6);

    return AuthPageWrapper(
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),

                // ── Logo ──────────────────────────────────────────────────
                const Center(child: SplitlyLogo(size: 64)),

                const SizedBox(height: 40),

                // ── Heading ───────────────────────────────────────────────
                Text(l10n.welcomeBack,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        color: headingColor,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text(l10n.signInToAccount,
                    style: TextStyle(
                        fontSize: 14, color: AppColors.primary)),

                const SizedBox(height: 28),

                // ── Email ─────────────────────────────────────────────────
                SplitlyTextField(
                  controller: _emailCtrl,
                  label: l10n.email,
                  hint: 'you@example.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.emailRequired;
                    if (!v.contains('@') || !v.contains('.'))
                      return l10n.enterValidEmail;
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // ── Password ──────────────────────────────────────────────
                SplitlyTextField(
                  controller: _passwordCtrl,
                  label: l10n.password,
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outlined,
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.passwordRequired;
                    if (v.length < 6) return l10n.atLeast6Chars;
                    return null;
                  },
                ),

                const SizedBox(height: 8),

                // ── Forgot password ───────────────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _goToForgotPassword,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                    ),
                    child: Text(l10n.forgotPassword,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Sign In button ────────────────────────────────────────
                SplitlyButton(
                    label: l10n.signIn,
                    isLoading: _isLoading,
                    onPressed: _login),

                const SizedBox(height: 20),

                // ── Divider ───────────────────────────────────────────────
                Row(children: [
                  Expanded(
                      child: Divider(color: dividerColor, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(l10n.orContinueWith,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryLight)),
                  ),
                  Expanded(
                      child: Divider(color: dividerColor, thickness: 1)),
                ]),

                const SizedBox(height: 20),

                // ── Google button — full width ────────────────────────────
                SplitlyGoogleButton(
                  isLoading: _isGoogleLoading,
                  onPressed: _googleSignIn,
                ),

                const SizedBox(height: 32),

                // ── "New to Splitly? Sign Up" link ────────────────────────
                // This is the ONLY sign up entry point — no duplicate button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.newToSplitly,
                        style: TextStyle(
                            fontSize: 13, color: linkMutedColor)),
                    GestureDetector(
                      onTap: _goToSignUp,
                      child: Text(l10n.signUp,
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}