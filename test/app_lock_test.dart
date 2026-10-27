// App lock PIN hashing and wrong-attempt back-off. Pure functions only —
// no secure storage or Supabase needed.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitly/features/security/controllers/app_lock_controller.dart';

void main() {
  group('pbkdf2Sha256', () {
    // RFC 7914 §11 test vector (PBKDF2-HMAC-SHA256, c = 1, first 32 bytes)
    test('matches the RFC 7914 test vector', () {
      final out = pbkdf2Sha256(utf8.encode('passwd'), utf8.encode('salt'), 1);
      expect(
        out.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc',
      );
    });

    // RFC 7914 §11, c = 80000
    test('matches the RFC 7914 test vector with many rounds', () {
      final out = pbkdf2Sha256(
          utf8.encode('Password'), utf8.encode('NaCl'), 80000);
      expect(
        out.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        '4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56',
      );
    });
  });

  group('PIN storage hash', () {
    test('right PIN verifies, wrong PIN does not', () {
      final stored = hashPinForStorage('1234', iterations: 1000);
      expect(verifyPinAgainstStored('1234', stored), isTrue);
      expect(verifyPinAgainstStored('1235', stored), isFalse);
    });

    test('same PIN gets a different salt every time', () {
      final a = hashPinForStorage('1234', iterations: 1000);
      final b = hashPinForStorage('1234', iterations: 1000);
      expect(a, isNot(b));
      expect(verifyPinAgainstStored('1234', a), isTrue);
      expect(verifyPinAgainstStored('1234', b), isTrue);
    });

    test('keeps the round count in the stored string', () {
      final stored = hashPinForStorage('0000', iterations: 1234);
      expect(stored.split('\$')[1], '1234');
    });

    test('garbage or old-format values never verify', () {
      expect(verifyPinAgainstStored('1234', ''), isFalse);
      expect(verifyPinAgainstStored('1234', legacySha256('1234')), isFalse);
      expect(verifyPinAgainstStored('1234', 'pbkdf2\$x\$a\$b'), isFalse);
    });

    test('legacy SHA-256 is the old unsalted hex digest', () {
      expect(legacySha256('1234'),
          '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4');
    });
  });

  group('lockoutFor', () {
    test('first 5 wrong tries are free', () {
      for (var i = 0; i < 5; i++) {
        expect(lockoutFor(i), Duration.zero);
      }
    });

    test('then 30s, doubling each time', () {
      expect(lockoutFor(5), const Duration(seconds: 30));
      expect(lockoutFor(6), const Duration(minutes: 1));
      expect(lockoutFor(7), const Duration(minutes: 2));
      expect(lockoutFor(8), const Duration(minutes: 4));
    });

    test('never more than 1 hour', () {
      expect(lockoutFor(12), const Duration(hours: 1));
      expect(lockoutFor(1000), const Duration(hours: 1));
    });
  });
}
