import 'package:supabase_flutter/supabase_flutter.dart';

/// Inserts/deletes rows in [tattsagram_likes]; DB triggers update [likes_count] on posts.
class TattsagramLikeService {
  TattsagramLikeService._();

  static SupabaseClient get _client => Supabase.instance.client;
  static const String _table = 'tattsagram_likes';

  static Future<Set<String>> fetchLikedPostIds(Iterable<String> postIds) async {
    final user = _client.auth.currentUser;
    final ids = postIds.where((id) => id.isNotEmpty).toList();
    if (user == null || ids.isEmpty) return {};

    final rows = await _client
        .from(_table)
        .select('post_id')
        .eq('user_id', user.id)
        .inFilter('post_id', ids);

    final out = <String>{};
    for (final row in rows) {
      final id = row['post_id'] as String?;
      if (id != null) out.add(id);
    }
    return out;
  }

  /// One insert is enough: `tattsagram_likes_sync_count` (see migrations) bumps
  /// [tattsagram_post.likes_count]. Do **not** also call an RPC that increments
  /// the counter — that would double-count.
  static Future<void> addLike({required String postId}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User must be authenticated');
    await _client.from(_table).insert({
      'user_id': user.id,
      'post_id': postId,
    });
  }

  static Future<void> removeLike({required String postId}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User must be authenticated');
    await _client
        .from(_table)
        .delete()
        .eq('user_id', user.id)
        .eq('post_id', postId);
  }
}
