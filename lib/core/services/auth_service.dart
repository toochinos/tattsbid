import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles authentication: sign in, sign out, and auth state.
/// Supabase persists sessions automatically (secure storage).
class AuthService {
  AuthService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Stream of auth state changes. Emits when user logs in or out.
  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  /// Signs in with email and password.
  static Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email, password: password);

  /// Signs up with email and password.
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) =>
      _client.auth.signUp(email: email, password: password);

  /// Signs out the current user. Clears persisted session.
  static Future<void> signOut() => _client.auth.signOut();
}
