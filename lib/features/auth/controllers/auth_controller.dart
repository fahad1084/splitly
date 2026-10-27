import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../notifications/controllers/fcm_service.dart';
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

    } on AuthException catch (e) {
      state = const AsyncValue.data(null);
      return e.message;
    } catch (e) {
      state = const AsyncValue.data(null);
      return 'Something went wrong. Please try again.';
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
    } on AuthException catch (e) {
      state = const AsyncValue.data(null);
      return e.message;
    } catch (e) {
      state = const AsyncValue.data(null);
      return 'Something went wrong. Please try again.';
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

      if (accessToken == null) {
        state = const AsyncValue.data(null);
        return 'Google sign in failed. Please try again.';
      }
      if (idToken == null) {
        state = const AsyncValue.data(null);
        return 'Google sign in failed. Please try again.';
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
    } on AuthException catch (e) {
      state = const AsyncValue.data(null);
      logDebug('=== GOOGLE SIGN-IN AuthException: ${e.message} ===');
      return e.message;
    } catch (e) {
      state = const AsyncValue.data(null);
      logDebug('=== GOOGLE SIGN-IN ERROR: $e ===');
      return 'Google sign in failed. Please try again.';
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
    } on AuthException catch (e) {
      state = const AsyncValue.data(null);
      return e.message;
    } catch (e) {
      state = const AsyncValue.data(null);
      return 'Something went wrong. Please try again.';
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
  // Anonymizes the profile (name → "Deleted User", strips personal data,
  // bans login) via a SECURITY DEFINER RPC — shared group/expense history
  // stays intact for other members. Signs the local session out afterward.
  Future<String?> deleteAccount() async {
    state = const AsyncValue.loading();
    try {
      await _supabase.rpc('delete_own_account');
      await signOut();
      state = const AsyncValue.data(null);
      return null;
    } on PostgrestException catch (e) {
      state = const AsyncValue.data(null);
      logDebug('=== DELETE ACCOUNT ERROR: ${e.message} ===');
      return 'Something went wrong. Please try again.';
    } catch (e) {
      state = const AsyncValue.data(null);
      logDebug('=== DELETE ACCOUNT ERROR: $e ===');
      return 'Something went wrong. Please try again.';
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