import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase/supabase_config.dart';

// ── Auth state stream ─────────────────────────────────────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseConfig.client.auth.onAuthStateChange;
});

// ── Current user ──────────────────────────────────────────────────────────────
final currentUserProvider = Provider<User?>((ref) {
  return SupabaseConfig.client.auth.currentUser;
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
        emailRedirectTo: 'com.yourname.splitly://callback',
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
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
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

  // ── Google Sign In ────────────────────────────────────────────────────────
  // Works for BOTH sign up and sign in — Google handles it automatically
  Future<String?> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      // ⚠️ Replace these with your actual IDs from Google Cloud Console
      // Web Client ID → from Phase A3 "Web Client ID" step
      const webClientId = '959683813994-1kqqb6jndb77ff37rejincam9u0ckl0k.apps.googleusercontent.com';

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

      final googleUser = await googleSignIn.signIn();
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
      return e.message;
    } catch (e) {
      state = const AsyncValue.data(null);
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
        redirectTo: 'com.example.splitly://callback',
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
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    } catch (_) {}
    await _supabase.auth.signOut();
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