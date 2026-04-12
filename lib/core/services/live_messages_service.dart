import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_service.dart';

/// Inserts rows into [live_messages] (Tattsagram live chat).
class LiveMessagesService {
  LiveMessagesService._();

  static SupabaseClient get _client => Supabase.instance.client;
  static const String _table = 'live_messages';

  /// [username] optional when the caller already resolved it (optimistic send).
  static Future<void> sendLiveMessage(
    String text, {
    String? username,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User must be authenticated');

    final resolved =
        username ?? await ProfileService.resolveLiveDisplayName();

    await _client.from(_table).insert({
      'user_id': user.id,
      'username': resolved,
      'message': trimmed,
    });
  }

  /// Realtime + initial fetch for [live_messages] (requires table in `supabase_realtime`).
  static Stream<List<Map<String, dynamic>>> liveChatStream() {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true);
  }
}
