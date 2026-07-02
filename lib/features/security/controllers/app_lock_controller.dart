import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

const _kPinKey = 'splitly_app_pin';
const _kLockEnabledKey = 'splitly_lock_enabled';
const _kBiometricEnabledKey = 'splitly_biometric_enabled';

class AppLockController extends StateNotifier<bool> {
  // state = true means app is currently LOCKED (needs PIN/biometric)
  AppLockController() : super(false);

  final _localAuth = LocalAuthentication();

  String _hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

  Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kLockEnabledKey) ?? false;
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBiometricEnabledKey) ?? false;
  }

  Future<bool> hasPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPinKey) != null;
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPinKey, _hashPin(pin));
    await prefs.setBool(_kLockEnabledKey, true);
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPinKey);
    if (saved == null) return false;
    return saved == _hashPin(pin);
  }

  Future<void> disableLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPinKey);
    await prefs.setBool(_kLockEnabledKey, false);
    await prefs.setBool(_kBiometricEnabledKey, false);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricEnabledKey, enabled);
  }

  Future<bool> canUseBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock Splitly',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      if (kDebugMode) print('Biometric auth error: $e');
      return false;
    }
  }

  void lock() => state = true;
  void unlock() => state = false;
}

final appLockControllerProvider =
StateNotifierProvider<AppLockController, bool>((ref) => AppLockController());