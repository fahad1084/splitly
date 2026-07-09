import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/screens/login_screen.dart';

const _kOnboardingDoneKey = 'splitly_onboarding_done';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  final _slides = [
    (icon: Icons.group_rounded, titleKey: 'onboardTitle1', descKey: 'onboardDesc1'),
    (icon: Icons.receipt_long_rounded, titleKey: 'onboardTitle2', descKey: 'onboardDesc2'),
    (icon: Icons.handshake_outlined, titleKey: 'onboardTitle3', descKey: 'onboardDesc3'),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingDoneKey, true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final textColor = dark ? AppColors.primaryTint : AppColors.primaryDark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(l10n.skip, style: TextStyle(color: AppColors.primary)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(slide.icon, size: 56, color: AppColors.primary),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          _titleFor(l10n, slide.titleKey),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w600, color: textColor),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _descFor(l10n, slide.descKey),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: AppColors.primary, height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SplitlyButton(
                label: _page == _slides.length - 1 ? l10n.getStarted : l10n.next,
                onPressed: () {
                  if (_page == _slides.length - 1) {
                    _finish();
                  } else {
                    _pageCtrl.nextPage(
                        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                  }
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _titleFor(AppLocalizations l10n, String key) {
    switch (key) {
      case 'onboardTitle1': return l10n.onboardTitle1;
      case 'onboardTitle2': return l10n.onboardTitle2;
      case 'onboardTitle3': return l10n.onboardTitle3;
      default: return '';
    }
  }

  String _descFor(AppLocalizations l10n, String key) {
    switch (key) {
      case 'onboardDesc1': return l10n.onboardDesc1;
      case 'onboardDesc2': return l10n.onboardDesc2;
      case 'onboardDesc3': return l10n.onboardDesc3;
      default: return '';
    }
  }
}

/// Checks if the user has already completed onboarding before.
/// Call this once at app start to decide whether to show onboarding.
Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingDoneKey) ?? false;
}