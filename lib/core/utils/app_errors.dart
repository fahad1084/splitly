import 'dart:async';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import 'app_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ERRORS → SHORT CODES → FRIENDLY TRANSLATED TEXT
// ─────────────────────────────────────────────────────────────────────────────
// Controllers never return raw error text. They call errorCode(), which logs
// the technical details (debug log + Crashlytics) and returns one of the
// codes below. Screens turn the code into text with friendlyError().

const kErrNetwork = 'NETWORK';
const kErrWrongLogin = 'WRONG_LOGIN';
const kErrEmailNotConfirmed = 'EMAIL_NOT_CONFIRMED';
const kErrEmailInUse = 'EMAIL_IN_USE';
const kErrWeakPassword = 'WEAK_PASSWORD';
const kErrTooManyTries = 'TOO_MANY_TRIES';
const kErrNotAllowed = 'NOT_ALLOWED';
const kErrNotSignedIn = 'NOT_SIGNED_IN';
const kErrGoogleSignIn = 'GOOGLE_SIGN_IN';
const kErrUnknown = 'UNKNOWN';

/// Works out the code for [error] (pure — no logging; unit-tested).
String codeForError(Object error) {
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is AuthRetryableFetchException) {
    return kErrNetwork;
  }
  if (error is AuthException) {
    final code = error.code ?? '';
    if (code == 'invalid_credentials') return kErrWrongLogin;
    if (code == 'email_not_confirmed') return kErrEmailNotConfirmed;
    if (code == 'user_already_exists' || code == 'email_exists') {
      return kErrEmailInUse;
    }
    if (code == 'weak_password') return kErrWeakPassword;
    if (code.startsWith('over_') || error.statusCode == '429') {
      return kErrTooManyTries;
    }
    return kErrUnknown;
  }
  if (error is PostgrestException) {
    // 42501 = row-level security said no; our RPCs raise 'NOT_ALLOWED'
    if (error.code == '42501' || error.message == 'NOT_ALLOWED') {
      return kErrNotAllowed;
    }
    return kErrUnknown;
  }
  // http package's ClientException (no import needed): "Failed host lookup",
  // "Connection closed" … — treat as no internet.
  if (error.runtimeType.toString() == 'ClientException') return kErrNetwork;
  return kErrUnknown;
}

/// Logs [error] and returns its code. The debug log gets the details; the
/// Crashlytics report gets only the error TYPE and CODE — never the message,
/// which can contain names, amounts or emails (see app_logger.dart).
String errorCode(Object error, StackTrace? stack, {required String where}) {
  final code = codeForError(error);
  logDebug('=== $where ERROR [$code]: $error ===');
  try {
    FirebaseCrashlytics.instance.recordError(
      _ErrorSummary(error), stack,
      reason: where, fatal: false,
    );
  } catch (_) {
    // Firebase not set up (tests) — the debug log above is enough
  }
  return code;
}

class _ErrorSummary {
  _ErrorSummary(Object error)
      : _text = switch (error) {
          PostgrestException(:final code) =>
            'PostgrestException(code: $code)',
          AuthException(:final code, :final statusCode) =>
            '${error.runtimeType}(code: $code, status: $statusCode)',
          _ => error.runtimeType.toString(),
        };
  final String _text;
  @override
  String toString() => _text;
}

/// Code (or null) → text for a snackbar. Anything unknown — including old
/// raw text — becomes the general "Something went wrong, please try again".
String friendlyError(AppLocalizations l10n, String? code) => switch (code) {
      kErrNetwork => l10n.errorNoInternet,
      kErrWrongLogin => l10n.errorWrongLogin,
      kErrEmailNotConfirmed => l10n.errorEmailNotConfirmed,
      kErrEmailInUse => l10n.errorEmailInUse,
      kErrWeakPassword => l10n.errorWeakPassword,
      kErrTooManyTries => l10n.errorTooManyTries,
      kErrNotAllowed => l10n.errorNotAllowed,
      kErrNotSignedIn => l10n.errorNotSignedIn,
      kErrGoogleSignIn => l10n.errorGoogleSignIn,
      _ => l10n.errorGeneric,
    };
