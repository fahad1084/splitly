import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'package:splitly/core/utils/app_logger.dart';
import '../../../config/supabase/supabase_config.dart';

// SharedPreferences — not secret. The "enabled" flag is also read by the
// push-notification background isolate (fcm_service.dart).
const kLockEnabledKey = 'splitly_lock_enabled';
const _kBiometricEnabledKey = 'splitly_biometric_enabled';
// Old unsalted SHA-256 PIN (before v1.2). Read once on unlock, then deleted.
const _kLegacyPinKey = 'splitly_app_pin';

// flutter_secure_storage (Android Keystore) — the PIN hash + attempt counter
const _kPinHashKey = 'splitly_pin_hash_v2';
const _kFailedAttemptsKey = 'splitly_pin_failed_attempts';
const _kLockedUntilKey = 'splitly_pin_locked_until';

const _kPbkdf2Iterations = 100000;
const _kFreeAttempts = 5;
const _kFirstLockout = Duration(seconds: 30);
const _kMaxLockout = Duration(hours: 1);

/// How long the app may stay in the background before it locks again.
const kLockGracePeriod = Duration(seconds: 30);

// ── PIN hashing (PBKDF2-HMAC-SHA256) ─────────────────────────────────────────
// Stored as "pbkdf2$<iterations>$<salt b64>$<hash b64>" so the cost can be
// raised later without breaking existing PINs.

@visibleForTesting
List<int> pbkdf2Sha256(List<int> password, List<int> salt, int iterations) {
  final hmac = Hmac(sha256, password);
  // One 32-byte block is enough (output length == SHA-256 length)
  var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final result = List<int>.from(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= u[j];
    }
  }
  return result;
}

@visibleForTesting
String hashPinForStorage(String pin, {List<int>? salt, int? iterations}) {
  final rounds = iterations ?? _kPbkdf2Iterations;
  final saltBytes = salt ??
      List<int>.generate(16, (_) => Random.secure().nextInt(256));
  final hash = pbkdf2Sha256(utf8.encode(pin), saltBytes, rounds);
  return 'pbkdf2\$$rounds\$${base64Encode(saltBytes)}\$${base64Encode(hash)}';
}

@visibleForTesting
bool verifyPinAgainstStored(String pin, String stored) {
  final parts = stored.split('\$');
  if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
  final rounds = int.tryParse(parts[1]);
  if (rounds == null) return false;
  final expected = base64Decode(parts[3]);
  final actual = pbkdf2Sha256(utf8.encode(pin), base64Decode(parts[2]), rounds);
  // Constant-time compare
  if (expected.length != actual.length) return false;
  var diff = 0;
  for (var i = 0; i < expected.length; i++) {
    diff |= expected[i] ^ actual[i];
  }
  return diff == 0;
}

@visibleForTesting
String legacySha256(String pin) => sha256.convert(utf8.encode(pin)).toString();

/// Wait time after [failures] wrong PINs in a row. The first 5 are free,
/// then 30s, 1m, 2m, 4m … up to 1 hour.
@visibleForTesting
Duration lockoutFor(int failures) {
  if (failures < _kFreeAttempts) return Duration.zero;
  final doublings = min(failures - _kFreeAttempts, 20);
  final seconds = _kFirstLockout.inSeconds * pow(2, doublings);
  return seconds >= _kMaxLockout.inSeconds
      ? _kMaxLockout
      : Duration(seconds: seconds.toInt());
}

// Isolate entry points for compute() — the hash takes a moment, keep the
// UI thread free.
String _hashInIsolate(String pin) => hashPinForStorage(pin);
bool _verifyInIsolate(List<String> args) =>
    verifyPinAgainstStored(args[0], args[1]);

/// Result of a PIN attempt.
enum PinResult { correct, wrong, lockedOut }

class AppLockController extends StateNotifier<bool> {
  // state = true means app is currently LOCKED (needs PIN/biometric)
  AppLockController() : super(false);

  final _localAuth = LocalAuthentication();
  static const _secure = FlutterSecureStorage();

  // ── Background tracking ──────────────────────────────────────────────────
  // Static so runWithoutLock() can be called from anywhere (services,
  // controllers) without a ref.
  static int _externalDepth = 0;
  static DateTime? _backgroundedAt;

  /// Run [action] (camera, gallery, cropper, share sheet, Google sign-in…)
  /// without the app locking when Android pauses us for it.
  static Future<T> runWithoutLock<T>(Future<T> Function() action) async {
    _externalDepth++;
    try {
      return await action();
    } finally {
      _externalDepth--;
      // Our own activity just returned — forget the pause it caused
      _backgroundedAt = null;
    }
  }

  /// Called by the lock overlay when the app goes to the background.
  void onBackgrounded() {
    if (_externalDepth > 0) return;
    _backgroundedAt ??= DateTime.now();
  }

  /// Called by the lock overlay when the app comes back. Locks only after
  /// a real break of at least [kLockGracePeriod].
  Future<void> onResumed() async {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (_externalDepth > 0 || since == null) return;
    if (DateTime.now().difference(since) < kLockGracePeriod) return;
    await lockIfEnabled();
  }

  /// Locks the app if the lock is on and someone is signed in.
  Future<void> lockIfEnabled() async {
    if (SupabaseConfig.client.auth.currentSession == null) return;
    if (await isLockEnabled()) _setLocked(true);
  }

  // ── Settings ─────────────────────────────────────────────────────────────

  Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(kLockEnabledKey) ?? false)) return false;
    // A restored backup can bring back the prefs flag without the Keystore
    // data. With no PIN there is nothing to unlock with — treat as off.
    return hasPinSet();
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBiometricEnabledKey) ?? false;
  }

  Future<bool> hasPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kLegacyPinKey) != null) return true;
    return await _read(_kPinHashKey) != null;
  }

  Future<void> setPin(String pin) async {
    final hash = await compute(_hashInIsolate, pin);
    await _secure.write(key: _kPinHashKey, value: hash);
    await _resetAttempts();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLegacyPinKey);
    await prefs.setBool(kLockEnabledKey, true);
  }

  /// Time left before another PIN may be tried (zero = may try now).
  Future<Duration> lockoutRemaining() async {
    final until = int.tryParse(await _read(_kLockedUntilKey) ?? '');
    if (until == null) return Duration.zero;
    final left = DateTime.fromMillisecondsSinceEpoch(until)
        .difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  Future<PinResult> verifyPin(String pin) async {
    if (await lockoutRemaining() > Duration.zero) return PinResult.lockedOut;

    final ok = await _checkPin(pin);
    if (ok) {
      await _resetAttempts();
      return PinResult.correct;
    }

    final failures =
        (int.tryParse(await _read(_kFailedAttemptsKey) ?? '') ?? 0) + 1;
    await _secure.write(key: _kFailedAttemptsKey, value: '$failures');
    final wait = lockoutFor(failures);
    if (wait > Duration.zero) {
      final until = DateTime.now().add(wait).millisecondsSinceEpoch;
      await _secure.write(key: _kLockedUntilKey, value: '$until');
      return PinResult.lockedOut;
    }
    return PinResult.wrong;
  }

  // Checks the new hash; falls back to the old SHA-256 once and migrates.
  Future<bool> _checkPin(String pin) async {
    final stored = await _read(_kPinHashKey);
    if (stored != null) return compute(_verifyInIsolate, [pin, stored]);

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_kLegacyPinKey);
    if (legacy == null || legacy != legacySha256(pin)) return false;

    // Correct old PIN → save it the new way, delete the old hash
    final hash = await compute(_hashInIsolate, pin);
    await _secure.write(key: _kPinHashKey, value: hash);
    await prefs.remove(_kLegacyPinKey);
    logDebug('App lock PIN migrated to PBKDF2');
    return true;
  }

  Future<void> _resetAttempts() async {
    await _secure.delete(key: _kFailedAttemptsKey);
    await _secure.delete(key: _kLockedUntilKey);
  }

  Future<String?> _read(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (e) {
      logDebug('Secure storage read error ($key): $e');
      return null;
    }
  }

  Future<void> disableLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLegacyPinKey);
    await prefs.setBool(kLockEnabledKey, false);
    await prefs.setBool(_kBiometricEnabledKey, false);
    await _secure.delete(key: _kPinHashKey);
    await _resetAttempts();
    _setLocked(false);
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
      final ok = await runWithoutLock(() => _localAuth.authenticate(
            localizedReason: 'Unlock Splitly',
            options: const AuthenticationOptions(
              biometricOnly: true,
              stickyAuth: true,
            ),
          ));
      if (ok) await _resetAttempts();
      return ok;
    } catch (e) {
      logDebug('Biometric auth error: $e');
      return false;
    }
  }

  /// Read synchronously by [AppLockBackGuard], which lives outside Riverpod.
  static bool get isLockedNow => _lockedNow;
  static bool _lockedNow = false;

  void _setLocked(bool locked) {
    _lockedNow = locked;
    state = locked;
  }

  void lock() => _setLocked(true);
  void unlock() => _setLocked(false);
}

final appLockControllerProvider =
StateNotifierProvider<AppLockController, bool>((ref) => AppLockController());

/// Registered in main() BEFORE runApp, so it sees the Android back button
/// before the Navigator does. While locked, back must not pop the screens
/// hidden under the lock.
class AppLockBackGuard with WidgetsBindingObserver {
  @override
  Future<bool> didPopRoute() async => AppLockController.isLockedNow;
}
