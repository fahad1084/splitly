import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/app_lock_controller.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  String _pin = '';
  String? _error;
  bool _checking = false;

  // Wrong-PIN wait (saved in secure storage, so it survives a restart)
  DateTime? _lockedUntil;
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    _loadLockout();
    _tryBiometricAuto();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  Duration get _waitLeft {
    final until = _lockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> _loadLockout() async {
    final left =
        await ref.read(appLockControllerProvider.notifier).lockoutRemaining();
    if (left > Duration.zero && mounted) _startCountdown(left);
  }

  void _startCountdown(Duration left) {
    _countdown?.cancel();
    setState(() => _lockedUntil = DateTime.now().add(left));
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_waitLeft == Duration.zero) {
        t.cancel();
        setState(() => _lockedUntil = null);
      } else {
        setState(() {}); // tick the countdown text
      }
    });
  }

  String _formatWait(Duration d) {
    final secs = d.inSeconds + 1; // round up, never show 0:00
    final m = secs ~/ 60;
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _tryBiometricAuto() async {
    final biometricEnabled =
    await ref.read(appLockControllerProvider.notifier).isBiometricEnabled();
    if (biometricEnabled && mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    final success =
    await ref.read(appLockControllerProvider.notifier).authenticateWithBiometrics();
    if (success && mounted) {
      _countdown?.cancel();
      ref.read(appLockControllerProvider.notifier).unlock();
    }
  }

  Future<void> _onKeyTap(String digit) async {
    if (_pin.length >= 4 || _checking || _waitLeft > Duration.zero) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _error = null;
      _pin += digit;
    });

    if (_pin.length == 4) {
      setState(() => _checking = true);
      final controller = ref.read(appLockControllerProvider.notifier);
      final result = await controller.verifyPin(_pin);
      if (!mounted) return;
      if (result == PinResult.correct) {
        controller.unlock();
        return;
      }
      HapticFeedback.heavyImpact();
      setState(() {
        _error = result == PinResult.wrong ? l10n.incorrectPin : null;
        _pin = '';
        _checking = false;
      });
      if (result == PinResult.lockedOut) {
        _startCountdown(await controller.lockoutRemaining());
      }
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _error = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = dark ? AppColors.primaryTint : AppColors.primaryDark;
    final dotColor = AppColors.primary;
    final waitLeft = _waitLeft;
    final message = waitLeft > Duration.zero
        ? l10n.tooManyPinAttempts(_formatWait(waitLeft))
        : _error;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_rounded, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.appName,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.enterPinToContinue,
              style: TextStyle(fontSize: 13, color: AppColors.primary),
            ),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? dotColor : Colors.transparent,
                    border: Border.all(color: dotColor, width: 2),
                  ),
                );
              }),
            ),

            if (message != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.dangerText(context), fontSize: 13)),
              ),
            ],

            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  _UnlockNumberPad(
                    textColor: waitLeft > Duration.zero
                        ? textColor.withOpacity(0.3)
                        : textColor,
                    onKeyTap: _onKeyTap,
                    onBackspace: _onBackspace,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _tryBiometric,
                    icon: Icon(Icons.fingerprint_rounded, color: AppColors.primary),
                    label: Text(l10n.useBiometricsButton, style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _UnlockNumberPad extends StatelessWidget {
  final Color textColor;
  final void Function(String) onKeyTap;
  final VoidCallback onBackspace;

  const _UnlockNumberPad({
    required this.textColor,
    required this.onKeyTap,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'back'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key.isEmpty) return const SizedBox(width: 64, height: 64);
              if (key == 'back') {
                return _Btn(
                  textColor: textColor,
                  child: Icon(Icons.backspace_outlined, size: 22, color: textColor),
                  onTap: onBackspace,
                );
              }
              return _Btn(
                textColor: textColor,
                child: Text(key,
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w500, color: textColor)),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onKeyTap(key);
                },
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _Btn extends StatelessWidget {
  final Widget child;
  final Color textColor;
  final VoidCallback onTap;
  const _Btn({required this.child, required this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(width: 64, height: 64, child: Center(child: child)),
      ),
    );
  }
}