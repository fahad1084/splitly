import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Is the phone online? ──────────────────────────────────────────────────────
// true while Wi-Fi or mobile data is on (connectivity_plus). Drives the
// "No internet" banner and the reload when the connection comes back.
// Starts as "online" so nothing flashes before the first check.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  try {
    yield _isOnline(await connectivity.checkConnectivity());
  } catch (_) {
    yield true; // can't tell — don't claim we're offline
  }
  yield* connectivity.onConnectivityChanged.map(_isOnline);
});

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);
