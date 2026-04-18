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

  /// Latest [limit] rows, oldest-first (for chat UI with newest at the bottom).
  static Future<List<LiveMessage>> fetchMessagesForChat({
    int limit = 100,
  }) async {
    final rows = await _client
        .from(_table)
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    final newestFirst = _rowsToLiveMessages(rows as List<dynamic>);
    return newestFirst.reversed.toList(growable: false);
  }

  /// Messages strictly older than [beforeUtc], oldest-first, up to [limit] rows.
  static Future<List<LiveMessage>> fetchMessagesOlderThan(
    DateTime beforeUtc, {
    int limit = 40,
  }) async {
    final iso = beforeUtc.toUtc().toIso8601String();
    final rows = await _client
        .from(_table)
        .select()
        .lt('created_at', iso)
        .order('created_at', ascending: false)
        .limit(limit);
    final newestFirst = _rowsToLiveMessages(rows as List<dynamic>);
    return newestFirst.reversed.toList(growable: false);
  }
}
