// Error → code → friendly text (lib/core/utils/app_errors.dart).

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:splitly/core/utils/app_errors.dart';
import 'package:splitly/l10n/app_localizations.dart';

void main() {
  group('codeForError', () {
    test('no internet', () {
      expect(codeForError(const SocketException('Failed host lookup')),
          kErrNetwork);
      expect(codeForError(TimeoutException('slow')), kErrNetwork);
      expect(codeForError(AuthRetryableFetchException()), kErrNetwork);
    });

    test('login / sign-up problems', () {
      expect(
          codeForError(const AuthException('Invalid login credentials',
              code: 'invalid_credentials')),
          kErrWrongLogin);
      expect(codeForError(const AuthException('x', code: 'email_not_confirmed')),
          kErrEmailNotConfirmed);
      expect(codeForError(const AuthException('x', code: 'user_already_exists')),
          kErrEmailInUse);
      expect(codeForError(const AuthException('x', code: 'weak_password')),
          kErrWeakPassword);
      expect(
          codeForError(
              const AuthException('x', code: 'over_email_send_rate_limit')),
          kErrTooManyTries);
      expect(codeForError(const AuthException('x', statusCode: '429')),
          kErrTooManyTries);
    });

    test('not allowed (RLS or our RPCs)', () {
      expect(
          codeForError(const PostgrestException(
              message: 'new row violates row-level security', code: '42501')),
          kErrNotAllowed);
      expect(codeForError(const PostgrestException(message: 'NOT_ALLOWED')),
          kErrNotAllowed);
    });

    test('anything else → UNKNOWN (never raw text)', () {
      expect(codeForError(Exception('boom')), kErrUnknown);
      expect(codeForError(const PostgrestException(message: 'duplicate key')),
          kErrUnknown);
      expect(codeForError(const AuthException('weird')), kErrUnknown);
    });
  });

  test('errorCode returns the code even without Firebase (tests)', () {
    expect(
        errorCode(const SocketException('x'), StackTrace.current, where: 'test'),
        kErrNetwork);
  });

  group('friendlyError', () {
    Future<AppLocalizations> l10nFor(WidgetTester t, String lang) async {
      late AppLocalizations l10n;
      await t.pumpWidget(Localizations(
        locale: Locale(lang),
        delegates: AppLocalizations.localizationsDelegates,
        child: Builder(builder: (c) {
          l10n = AppLocalizations.of(c)!;
          return const SizedBox();
        }),
      ));
      return l10n;
    }

    testWidgets('codes become translated text; unknown/raw → general text',
        (t) async {
      final en = await l10nFor(t, 'en');
      expect(friendlyError(en, kErrNetwork), en.errorNoInternet);
      expect(friendlyError(en, kErrWrongLogin), 'Wrong email or password.');
      expect(friendlyError(en, 'Error: PostgrestException(...)'),
          en.errorGeneric);
      expect(friendlyError(en, null), en.errorGeneric);

      final ur = await l10nFor(t, 'ur');
      expect(friendlyError(ur, kErrWrongLogin), 'ای میل یا پاس ورڈ غلط ہے۔');
    });
  });
}
