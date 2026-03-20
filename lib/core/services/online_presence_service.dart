import 'package:supabase_flutter/supabase_flutter.dart';

/// Updates user's online presence (last_seen).
class OnlinePresenceService {
  OnlinePresenceService._();

  /// Returns true if lastSeen is within 2 minutes.
  static bool isOnline(DateTime lastSeen) {
    return DateTime.now().difference(lastSeen).inMinutes < 2;
  }

  /// Upserts the current user's last_seen timestamp.
  static Future<void> updatePresence() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Supabase.instance.client.from('online_users').upsert({
      'user_id': Supabase.instance.client.auth.currentUser!.id,
      'last_seen': DateTime.now().toIso8601String(),
    });
  }

  /// Fetches online users.
  static Future<List<dynamic>> fetchOnlineUsers() async {
    final users = await Supabase.instance.client.from('online_users').select();
    return users as List;
  }
}
