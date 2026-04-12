import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/live_message.dart';
import 'profile_service.dart';

/// Inserts rows into [live_messages] (Tattsagram live chat).
///
/// [message] must be a raw Dart [String]. PostgREST JSON encodes it as UTF-8 into
/// PostgreSQL `text`. Never use utf8.encode, latin1.encode, codeUnits, runes for
/// storage, or String.fromCharCodes for the payload.
class LiveMessagesService {
  LiveMessagesService._();

  static SupabaseClient get _client => Supabase.instance.client;
  static const String _table = 'live_messages';

  static List<LiveMessage> _rowsToLiveMessages(List<dynamic> rows) {
    return rows
        .map(
          (e) => LiveMessage.fromRow(
            Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
          ),
        )
        .toList(growable: false);
  }

  /// [username] optional when the caller already resolved it (optimistic send).
  static Future<void> sendLiveMessage(
    String text, {
    String? username,
  }) async {
    if (text.trim().isEmpty) return;

    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User must be authenticated');

    final resolved = username ?? await ProfileService.resolveLiveDisplayName();

    await _client.from(_table).insert({
      'user_id': user.id,
      'username': resolved,
      'message': text,
    });
  }

  /// Realtime + initial fetch for [live_messages] (requires table in `supabase_realtime`).
  static Stream<List<LiveMessage>> liveChatStream() {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((rows) => _rowsToLiveMessages(rows as List<dynamic>));
  }

  /// REST fetch so UI updates even if the Realtime WebSocket misses events (polling backup).
  static Future<List<LiveMessage>> fetchMessagesForChat({
    int limit = 300,
  }) async {
    final rows = await _client
        .from(_table)
        .select()
        .order('created_at', ascending: true)
        .limit(limit);
    return _rowsToLiveMessages(rows as List<dynamic>);
  }
}
