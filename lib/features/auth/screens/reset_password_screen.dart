import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;

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
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      // At this point the user is temporarily signed in via the recovery token
      // updateUser sets the new password — this fires userUpdated event
      // AuthGate catches userUpdated and navigates to LoginScreen
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: _passwordCtrl.text),
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });

      // Brief success state, then AuthGate handles navigation via userUpdated
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showErrorSnack(context, l10n.updatePasswordFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final headingColor =
    dark ? AppColors.primaryTint : AppColors.primaryDark;
    final iconBg = dark ? AppColors.primaryDark : AppColors.primaryTint;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _isSuccess
                    ? _successView(iconBg, headingColor)
                    : _formView(iconBg, headingColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Form view ──────────────────────────────────────────────────────────────
  Widget _formView(Color iconBg, Color headingColor) {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),

          // Logo — same as all auth screens
          const Center(child: SplitlyLogo(size: 64)),

          const SizedBox(height: 40),

          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            l10n.setNewPassword,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: headingColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.enterConfirmNewPassword,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.primary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 28),

          // New password
          SplitlyTextField(
            controller: _passwordCtrl,
            label: l10n.newPassword,
            hint: '••••••••',
            prefixIcon: Icons.lock_outlined,
            obscureText: true,
            autofocus: true,
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.passwordRequired;
              if (v.length < 6) return l10n.atLeast6Chars;
              return null;
            },
          ),

          const SizedBox(height: 14),

          // Confirm new password
          SplitlyTextField(
            controller: _confirmCtrl,
            label: l10n.confirmNewPassword,
            hint: '••••••••',
            prefixIcon: Icons.lock_outlined,
            obscureText: true,
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.confirmYourPassword;
              if (v != _passwordCtrl.text) return l10n.passwordsDoNotMatch;
              return null;
            },
          ),

          const SizedBox(height: 28),

          SplitlyButton(
            label: l10n.updatePassword,
            isLoading: _isLoading,
            onPressed: _updatePassword,
            icon: Icons.check_rounded,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Success view ───────────────────────────────────────────────────────────
  Widget _successView(Color iconBg, Color headingColor) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 42,
              color: AppColors.success,
            ),
          ),

          const SizedBox(height: 24),

          Text(
            l10n.passwordUpdated,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: headingColor,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            l10n.passwordUpdatedDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.primary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 28),

          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}