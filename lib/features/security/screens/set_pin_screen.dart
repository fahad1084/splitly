import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../controllers/app_lock_controller.dart';

class SetPinScreen extends ConsumerStatefulWidget {
  const SetPinScreen({super.key});

  @override
  ConsumerState<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends ConsumerState<SetPinScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirmStep = false;
  String? _error;

  void _onKeyTap(String digit) {
    setState(() {
      _error = null;
      if (!_isConfirmStep) {
        if (_pin.length < 4) _pin += digit;
        if (_pin.length == 4) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) setState(() => _isConfirmStep = true);
          });
        }
      } else {
        if (_confirmPin.length < 4) _confirmPin += digit;
        if (_confirmPin.length == 4) {
          _validateAndSave();
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      _error = null;
      if (!_isConfirmStep) {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      }
    });
  }

  Future<void> _validateAndSave() async {
    if (_pin != _confirmPin) {
      setState(() {
        _error = 'PINs do not match. Try again.';
        _confirmPin = '';
        _isConfirmStep = false;
        _pin = '';
      });
      HapticFeedback.heavyImpact();
      return;
    }

    await ref.read(appLockControllerProvider.notifier).setPin(_pin);
    if (mounted) {
      showSuccessSnack(context, 'App Lock enabled!');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final textColor = dark ? AppColors.primaryTint : AppColors.primaryDark;
    final activeDigits = _isConfirmStep ? _confirmPin.length : _pin.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Set App PIN')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Icon(Icons.lock_outline_rounded, size: 56, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              _isConfirmStep ? 'Confirm your PIN' : 'Create a 4-digit PIN',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              _isConfirmStep ? 'Enter the same PIN again' : 'You\'ll use this to unlock Splitly',
              style: TextStyle(fontSize: 13, color: AppColors.primary),
            ),
            const SizedBox(height: 24),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < activeDigits;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColors.primary : Colors.transparent,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                );
              }),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
            ],

            const Spacer(),

            // Number pad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _NumberPad(onKeyTap: _onKeyTap, onBackspace: _onBackspace),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  final void Function(String) onKeyTap;
  final VoidCallback onBackspace;

  const _NumberPad({required this.onKeyTap, required this.onBackspace});

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
                return _PadButton(
                  child: const Icon(Icons.backspace_outlined, size: 22),
                  onTap: onBackspace,
                );
              }
              return _PadButton(
                child: Text(key, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
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

class _PadButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PadButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final textColor = dark ? AppColors.primaryTint : AppColors.primaryDark;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 64,
          height: 64,
          child: Center(
            child: DefaultTextStyle(
              style: TextStyle(color: textColor),
              child: IconTheme(
                data: IconThemeData(color: textColor),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}