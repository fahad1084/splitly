import 'package:flutter/foundation.dart';

/// Debug-only log line. Prints nothing in release (and profile) builds, so
/// nothing ends up in `adb logcat` on users' phones.
///
/// Rule: never pass tokens, passwords or user data (names, messages,
/// amounts, database rows) — log what went wrong, not whose data it was.
/// Real crashes are reported by Firebase Crashlytics (see main.dart).
void logDebug(String message) {
  if (kDebugMode) debugPrint(message);
}
