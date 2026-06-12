import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_deletion_local_cleanup.dart';
import 'auth_service.dart';
import 'online_heartbeat_service.dart';
import 'online_presence_service.dart';

/// Server-side GDPR account deletion via the `delete-user` edge function.
class AccountDeletionService {
  AccountDeletionService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Invokes [delete-user] while the session JWT is valid, then clears local
  /// data and exits to the device home screen.
  ///
  /// Throws [AccountDeletionException] with a user-facing [message] on failure.
  static Future<void> deleteAccount() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw AccountDeletionException('Not signed in.');
    }

    final userId = _client.auth.currentUser?.id;

    try {
      await _client.auth.refreshSession();
    } catch (e) {
      debugPrint('delete-user: session refresh failed: $e');
    }

    if (_client.auth.currentSession == null) {
      throw AccountDeletionException('Session expired. Sign in again.');
    }

    OnlineHeartbeatService.stop();
    if (userId != null) {
      try {
        await OnlinePresenceService.clearPresence(forUserId: userId);
      } catch (e) {
        debugPrint('delete-user: presence clear before delete: $e');
      }
    }

    try {
      final response = await _client.functions.invoke('delete-user');

      debugPrint(
        'delete-user: status=${response.status} data=${response.data}',
      );

      final data = response.data;
      final success = data is Map && data['success'] == true;
      if (response.status != 200 || !success) {
        var reason = 'HTTP ${response.status}';
        var step = 'unknown';
        if (data is Map) {
          if (data['error'] != null) {
            reason = data['error'].toString();
          }
          if (data['step'] != null) {
            step = data['step'].toString();
          }
        }
        throw AccountDeletionException(
          step == 'unknown' ? reason : '$reason (step: $step)',
        );
      }

      await AccountDeletionLocalCleanup.clearUserLocalData();
      AuthService.leaveAppAfterAccountDeletion();
    } on FunctionException catch (e) {
      final detail = e.details?.toString() ?? e.toString();
      throw AccountDeletionException(detail);
    } on AccountDeletionException {
      rethrow;
    } catch (e) {
      throw AccountDeletionException(e.toString());
    }
  }
}

class AccountDeletionException implements Exception {
  AccountDeletionException(this.message);

  final String message;

  @override
  String toString() => message;
}
