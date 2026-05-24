import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_service.dart';

/// Heartbeat row in [live_online] (who is active in Tattsagram live).
class LiveOnlineService {
  LiveOnlineService._();

  static SupabaseClient get _client => Supabase.instance.client;
  static const String _table = 'live_online';

  static Future<void> setOnline() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final username = await ProfileService.resolveLiveDisplayName();

    await _client.from(_table).upsert(
      {
        'user_id': user.id,
        'username': username,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id',
    );
  }

  /// Count of rows in [live_online] with [last_seen] within the last 2 minutes.
  ///
  /// Cutoff is recomputed on each stream event so stale users drop off without
  /// waiting for another DB change.
  static Stream<int> onlineUsers() {
    return _client.from(_table).stream(primaryKey: ['user_id']).map((users) {
      final cutoff =
          DateTime.now().toUtc().subtract(const Duration(minutes: 2));
      return users.where((u) {
        final raw = u['last_seen'];
        if (raw == null) return false;
        final t = DateTime.tryParse(raw.toString());
        if (t == null) return false;
        return t.toUtc().isAfter(cutoff);
      }).length;
    });
  }
}
