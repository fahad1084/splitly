import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
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

  @override
  void initState() {
    super.initState();
    _tryBiometricAuto();
  }

  Future<void> _tryBiometricAuto() async {
    final biometricEnabled = await ref.read(appLockControllerProvider.notifier).isBiometricEnabled();
    if (biometricEnabled && mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    final success = await ref.read(appLockControllerProvider.notifier).authenticateWithBiometrics();
    if (success && mounted) {
      ref.read(appLockControllerProvider.notifier).unlock();
    }
  }

  Future<void> _onKeyTap(String digit) async {
    if (_pin.length >= 4 || _checking) return;
    setState(() {
      _error = null;
      _pin += digit;
    });

    if (_pin.length == 4) {
      setState(() => _checking = true);
      final valid = await ref.read(appLockControllerProvider.notifier).verifyPin(_pin);
      if (valid) {
        ref.read(appLockControllerProvider.notifier).unlock();
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _error = 'Incorrect PIN. Try again.';
          _pin = '';
          _checking = false;
        });
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
    final dark = isDark(context);
    final textColor = dark ? AppColors.primaryTint : AppColors.primaryDark;

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            SizedBox(
              width: 64,
              height: 64,
              child: Icon(Icons.lock_rounded, size: 56, color: AppColors.primaryTint),
            ),
            const SizedBox(height: 16),
            Text(
              'Splitly',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.primaryTint),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your PIN to continue',
              style: TextStyle(fontSize: 13, color: AppColors.accent),
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
                    color: filled ? AppColors.primaryTint : Colors.transparent,
                    border: Border.all(color: AppColors.primaryTint, width: 2),
                  ),
                );
              }),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
            ],

            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  _UnlockNumberPad(onKeyTap: _onKeyTap, onBackspace: _onBackspace),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _tryBiometric,
                    icon: const Icon(Icons.fingerprint_rounded, color: AppColors.primaryTint),
                    label: Text('Use biometrics',
                        style: TextStyle(color: AppColors.primaryTint)),
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
  final void Function(String) onKeyTap;
  final VoidCallback onBackspace;

  const _UnlockNumberPad({required this.onKeyTap, required this.onBackspace});

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
                  child: const Icon(Icons.backspace_outlined,
                      size: 22, color: AppColors.primaryTint),
                  onTap: onBackspace,
                );
              }
              return _Btn(
                child: Text(key,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w500, color: AppColors.primaryTint)),
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
  final VoidCallback onTap;
  const _Btn({required this.child, required this.onTap});

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