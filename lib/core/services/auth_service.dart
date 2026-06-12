import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/link_handler.dart';
import '../routes/app_routes.dart';
import 'online_heartbeat_service.dart';
import 'online_presence_service.dart';

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
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    debugPrint('AuthService: signed in user_id=${response.user?.id}');
    OnlineHeartbeatService.start();
    return response;
  }

  /// Signs up with email and password.
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    if (response.session != null) {
      debugPrint('AuthService: signed up user_id=${response.user?.id}');
      OnlineHeartbeatService.start();
    }
    return response;
  }

  /// Clears session and presence only (no navigation).
  static Future<void> signOut() async {
    final userId = _client.auth.currentUser?.id;
    OnlineHeartbeatService.stop();
    if (userId != null) {
      await OnlinePresenceService.clearPresence(forUserId: userId);
    }
    await _client.auth.signOut();
    debugPrint('AuthService: signed out user_id=$userId');
  }

  /// Sign out from Settings: clear session then exit to the device home screen.
  static Future<void> signOutAndLeaveApp() async {
    debugPrint('AuthService: signOutAndLeaveApp');
    await signOut();
    _exitAppToHomeScreen();
  }

  /// Sign out and show login (e.g. after account deletion message).
  static Future<void> signOutAndReturnToLogin() async {
    debugPrint('AuthService: signOutAndReturnToLogin');
    await signOut();
    _navigateToLoginClearingStack();
  }

  /// After account deletion: return to the device home screen (iPhone/Android).
  static void leaveAppAfterAccountDeletion() {
    debugPrint('AuthService: leaveAppAfterAccountDeletion');
    _exitAppToHomeScreen();
  }

  /// Legacy: login screen with deletion message (not used after delete flow).
  static void navigateToLoginAfterAccountDeletion() {
    debugPrint('AuthService: navigateToLoginAfterAccountDeletion');
    final nav = LinkHandler.navigatorKey.currentState;
    if (nav == null) {
      debugPrint(
        'AuthService: navigator not ready — StartupRouter will show login',
      );
      return;
    }
    nav.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
      arguments: {AppRoutes.showAccountDeletedMessageArg: true},
    );
    debugPrint('AuthService: navigated to login after account deletion');
  }

  static void _navigateToLoginClearingStack() {
    final nav = LinkHandler.navigatorKey.currentState;
    if (nav == null) {
      debugPrint(
        'AuthService: navigator not ready — StartupRouter will show login',
      );
      return;
    }
    nav.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    debugPrint('AuthService: navigated to login (stack cleared)');
  }

  /// Returns the user to the iOS/Android home screen (not an in-app login page).
  static void _exitAppToHomeScreen() {
    debugPrint('AuthService: exiting app after sign out');
    if (Platform.isAndroid) {
      SystemNavigator.pop();
      return;
    }
    if (Platform.isIOS || Platform.isMacOS) {
      // iOS has no supported “go home” API; terminate so the user leaves the app.
      exit(0);
    }
    SystemNavigator.pop();
  }
}
