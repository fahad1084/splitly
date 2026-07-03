import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/auth_controller.dart';
import 'home_screen.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
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
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    final error = await ref.read(authControllerProvider.notifier).signUp(
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      showErrorSnack(context, error);
    } else {
      showSuccessSnack(context, l10n.accountCreatedCheckEmail);
      // ✅ No navigation here — go back to login so user can sign in
      Navigator.pop(context);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isGoogleLoading = true);
    final error =
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    if (error != null) showErrorSnack(context, error);
    // ✅ No navigation here — AuthGate handles it automatically on signedIn event
  }
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
      showBackButton: true,
      title: l10n.createAccountTitle,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // ── Logo — exactly matching login screen ──────────────────
                const Center(child: SplitlyLogo(size: 64)),

                const SizedBox(height: 32),

                // ── Heading ───────────────────────────────────────────────
                Text(l10n.joinSplitly,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        color: headingColor,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text(l10n.splitExpensesCircle,
                    style: TextStyle(
                        fontSize: 14, color: AppColors.primary)),

                const SizedBox(height: 28),

                // ── Full Name ─────────────────────────────────────────────
                SplitlyTextField(
                  controller: _nameCtrl,
                  label: l10n.fullName,
                  hint: 'Ahmed Khan',
                  prefixIcon: Icons.person_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return l10n.nameRequired;
                    if (v.trim().length < 2) return l10n.nameTooShort;
                    return null;
                  },
                ),

                const SizedBox(height: 14),

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

                const SizedBox(height: 14),

                // ── Confirm Password ──────────────────────────────────────
                SplitlyTextField(
                  controller: _confirmCtrl,
                  label: l10n.confirmPassword,
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outlined,
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return l10n.confirmYourPassword;
                    if (v != _passwordCtrl.text)
                      return l10n.passwordsDoNotMatch;
                    return null;
                  },
                ),

                const SizedBox(height: 28),

                // ── Create Account button ─────────────────────────────────
                SplitlyButton(
                    label: l10n.createAccount,
                    isLoading: _isLoading,
                    onPressed: _signUp),

                const SizedBox(height: 20),

                // ── Divider — same as login ────────────────────────────────
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

                // ── Google button — same as login ─────────────────────────
                SplitlyGoogleButton(
                  isLoading: _isGoogleLoading,
                  onPressed: _googleSignIn,
                ),

                const SizedBox(height: 32),

                // ── Already have account link ─────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.alreadyHaveAccount,
                        style: TextStyle(
                            fontSize: 13, color: linkMutedColor)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(l10n.signIn,
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