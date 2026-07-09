import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/auth_controller.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  late AnimationController _entryCtrl;
  late AnimationController _successCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _successFade;
  late Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _fadeAnim =
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _successFade =
        CurvedAnimation(parent: _successCtrl, curve: Curves.easeOut);
    _successScale = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(
            parent: _successCtrl, curve: Curves.easeOutBack));

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _successCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final error = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(_emailCtrl.text.trim());
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      showErrorSnack(context, error);
    } else {
      setState(() => _emailSent = true);
      _successCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AuthPageWrapper(
      showBackButton: true,
      title: l10n.resetPasswordTitle,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _emailSent ? _successView() : _formView(),
      ),
    );
  }

  Widget _formView() {
    final l10n = AppLocalizations.of(context)!;
    final headingColor =
    isDark(context) ? AppColors.primaryTint : AppColors.primaryDark;
    final iconBg =
    isDark(context) ? AppColors.primaryDark : AppColors.primaryTint;

    return FadeTransition(
      key: const ValueKey('form'),
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

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

              Text(l10n.forgotYourPassword,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                      color: headingColor,
                      letterSpacing: -0.5,
                      height: 1.2)),

              const SizedBox(height: 8),

              Text(
                  l10n.resetLinkDesc,
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                      height: 1.5)),

              const SizedBox(height: 28),

              SplitlyTextField(
                controller: _emailCtrl,
                label: l10n.email,
                hint: 'you@example.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.emailRequired;
                  if (!v.contains('@') || !v.contains('.'))
                    return l10n.enterValidEmail;
                  return null;
                },
              ),

              const SizedBox(height: 24),

              SplitlyButton(
                label: l10n.sendResetLink,
                isLoading: _isLoading,
                onPressed: _resetPassword,
                icon: Icons.send_rounded,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _successView() {
    final l10n = AppLocalizations.of(context)!;
    final headingColor =
    isDark(context) ? AppColors.primaryTint : AppColors.primaryDark;
    final emailColor =
    isDark(context) ? AppColors.primaryTint : AppColors.primaryDark;
    final infoBg =
    isDark(context) ? AppColors.primaryDark : AppColors.primaryTint;
    final iconBg =
    isDark(context) ? AppColors.primaryDark : AppColors.primaryTint;

    return FadeTransition(
      key: const ValueKey('success'),
      opacity: _successFade,
      child: ScaleTransition(
        scale: _successScale,
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Check circle
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                    color: iconBg, shape: BoxShape.circle),
                child: const Icon(Icons.mark_email_read_outlined,
                    size: 42, color: AppColors.primary),
              ),

              const SizedBox(height: 28),

              Text(l10n.checkYourEmail,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: headingColor,
                      letterSpacing: -0.5)),

              const SizedBox(height: 10),

              Text(l10n.weSentResetLink,
                  style:
                  TextStyle(fontSize: 14, color: AppColors.primary),
                  textAlign: TextAlign.center),

              const SizedBox(height: 4),

              Text(_emailCtrl.text,
                  style: TextStyle(
                      fontSize: 14,
                      color: emailColor,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center),

              const SizedBox(height: 16),

              // Info box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: infoBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.checkSpamFolder,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          height: 1.4),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 32),

              SplitlyButton(
                label: l10n.backToSignIn,
                onPressed: () => Navigator.pop(context),
                icon: Icons.arrow_back_rounded,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}