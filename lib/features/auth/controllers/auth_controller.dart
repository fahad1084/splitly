import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../notifications/controllers/fcm_service.dart';
import 'package:splitly/core/utils/app_errors.dart';
import 'package:splitly/core/utils/app_logger.dart';
import '../../security/controllers/app_lock_controller.dart';

// ── Auth state stream ─────────────────────────────────────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseConfig.client.auth.onAuthStateChange;
});

// ── Current user ──────────────────────────────────────────────────────────────
final currentUserProvider = Provider<User?>((ref) {
  return SupabaseConfig.client.auth.currentUser;
});

// ── My profile row (name, avatar_color, avatar_url, phone) ────────────────────
final myProfileProvider =
FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId = SupabaseConfig.client.auth.currentUser?.id;
  if (userId == null) return null;
  try {
    final data = await SupabaseConfig.client
        .from('profiles')
        .select('full_name, avatar_color, avatar_url, phone')
        .eq('id', userId)
        .maybeSingle();
    return data;
  } catch (e) {
    logDebug('=== FETCH MY PROFILE ERROR: $e ===');
    return null;
  }
});

// ── Auth controller provider ──────────────────────────────────────────────────
final authControllerProvider =
StateNotifierProvider<AuthController, AsyncValue<void>>(
      (ref) => AuthController(),
);

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController() : super(const AsyncValue.data(null));

  final _supabase = SupabaseConfig.client;

  // ── Email Sign Up ─────────────────────────────────────────────────────────
  Future<String?> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
        emailRedirectTo: 'com.splitly.app://callback',
      );

      // Try to create profile — but don't fail sign up if this fails
      if (response.user != null) {
        try {
          await _createProfile(
            id: response.user!.id,
            fullName: fullName,
          );
        } catch (_) {
          // Profile will be created on first login instead
        }
      }

      state = const AsyncValue.data(null);
      return null; // ← success regardless of profile insert

    } catch (e, st) {
      // A code, never raw text — the screen shows a translated message
      state = const AsyncValue.data(null);
      return errorCode(e, st, where: 'signUp');
    }
  }

  // ── Email Sign In ─────────────────────────────────────────────────────────
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Safety-net: create profile if it's missing (e.g. it failed silently
      // during signUp) — same pattern used for Google sign-in.
      if (response.user != null) {
        try {
          await _createProfileIfNotExists(
            id: response.user!.id,
            fullName: (response.user!.userMetadata?['full_name'] as String?)
                ?? email.split('@')[0],
          );
        } catch (_) {
          // Don't block login if this fails — expense/group actions will
          // surface the issue clearly if profile is still missing.
        }
      }

      state = const AsyncValue.data(null);
      return null;
    } catch (e, st) {
      // A code, never raw text — the screen shows a translated message
      state = const AsyncValue.data(null);
      return errorCode(e, st, where: 'signIn');
    }
  }

  // ── Google Sign In ────────────────────────────────────────────────────────
  // Works for BOTH sign up and sign in — Google handles it automatically
  Future<String?> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      // ⚠️ Replace these with your actual IDs from Google Cloud Console
      // Web Client ID → from Phase A3 "Web Client ID" step
      const webClientId = '280568730972-j7f22jtmkimgdsbqbcilb81ct4qq1eti.apps.googleusercontent.com';

      final googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
        scopes: [
          'email',
          'profile',
          'openid',
          'https://www.googleapis.com/auth/userinfo.email',
          'https://www.googleapis.com/auth/userinfo.profile',
        ],
      );

      final googleUser =
          await AppLockController.runWithoutLock(googleSignIn.signIn);
      if (googleUser == null) {
        state = const AsyncValue.data(null);
        return null; // user cancelled
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        state = const AsyncValue.data(null);
        return kErrGoogleSignIn;
      }

      // Sign in to Supabase with Google tokens
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Create profile row if this is first time (new user)
      if (response.user != null) {
        await _createProfileIfNotExists(
          id: response.user!.id,
          fullName: googleUser.displayName ??
              googleUser.email.split('@')[0],
        );
      }

      state = const AsyncValue.data(null);
      return null;
    } catch (e, st) {
      state = const AsyncValue.data(null);
      final code = errorCode(e, st, where: 'googleSignIn');
      // e.g. a PlatformException from the Google picker
      return code == kErrUnknown ? kErrGoogleSignIn : code;
    }
  }

  // ── Forgot Password ───────────────────────────────────────────────────────
  Future<String?> resetPassword(String email) async {
    state = const AsyncValue.loading();
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        // This tells Supabase to redirect back to your app after clicking the link
        // Must match what you added in Supabase → Authentication → URL Configuration
        redirectTo: 'com.splitly.app://callback',
      );
      state = const AsyncValue.data(null);
      return null;
    } catch (e, st) {
      // A code, never raw text — the screen shows a translated message
      state = const AsyncValue.data(null);
      return errorCode(e, st, where: 'resetPassword');
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    // Clear this device's push token while the session is still valid,
    // so the logged-out user's notifications stop coming to this phone.
    await FCMService().clearTokenFromSupabase();
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    } catch (_) {}
    await _supabase.auth.signOut();
  }

  // ── Delete Account ────────────────────────────────────────────────────────
  // delete_own_account() (20261031000100_account_deletion.sql) anonymizes
  // the profile, leaves all groups and bans the login — shared group history
  // stays intact for other members. It refuses with HAS_UNSETTLED_DEBTS while
  // money is still owed either way; then NOTHING is deleted (not the photo
  // either). After it worked, the profile photo files are removed and the
  // local session is signed out.
  Future<String?> deleteAccount() async {
    state = const AsyncValue.loading();
    final userId = _supabase.auth.currentUser?.id;
    try {
      await _supabase.rpc('delete_own_account');
    } on PostgrestException catch (e, st) {
      state = const AsyncValue.data(null);
      if (e.message == 'HAS_UNSETTLED_DEBTS') return 'HAS_UNSETTLED_DEBTS';
      return errorCode(e, st, where: 'deleteAccount');
    } catch (e, st) {
      state = const AsyncValue.data(null);
      return errorCode(e, st, where: 'deleteAccount');
    }

    if (userId != null) await _deleteMyAvatarFiles(userId);
    try {
      await signOut();
    } catch (e) {
      // The account is already deleted; the session ends on the next
      // token refresh anyway (the login is banned).
      logDebug('=== signOut after deleting the account: $e ===');
    }
    state = const AsyncValue.data(null);
    return null;
  }

  // Postgres may not delete Storage files, so the app does it through the
  // Storage API (only your own avatars/<id>/ folder is allowed). Best
  // effort: if it fails, nothing points to the file any more.
  Future<void> _deleteMyAvatarFiles(String userId) async {
    try {
      final storage = _supabase.storage.from('avatars');
      final files = await storage.list(path: userId);
      if (files.isNotEmpty) {
        await storage.remove([for (final f in files) '$userId/${f.name}']);
      }
    } catch (e) {
      logDebug('=== delete avatar files: $e ===');
    }
  }

  // ── Private: create profile on first sign up ──────────────────────────────
  Future<void> _createProfile({
    required String id,
    required String fullName,
  }) async {
    await _supabase.from('profiles').upsert({
      'id': id,
      'full_name': fullName,
      'avatar_color': _randomAvatarColor(),
    });
  }

  // ── Private: create profile only if it doesn't exist (social logins) ──────
  Future<void> _createProfileIfNotExists({
    required String id,
    required String fullName,
  }) async {
    final existing = await _supabase
        .from('profiles')
        .select('id')
        .eq('id', id)
        .maybeSingle();
    if (existing == null) {
      await _createProfile(id: id, fullName: fullName);
    }
  }

  // ── Private: random avatar color from Splitly palette ────────────────────
  String _randomAvatarColor() {
    const colors = [
      '#0F766E', '#134E4A', '#14B8A6',
      '#EAB308', '#CA8A04', '#16A34A',
    ];
    return colors[Random().nextInt(colors.length)];
  }
}