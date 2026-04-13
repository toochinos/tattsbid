import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tattsagram_post.dart';

class TattsagramPostService {
  TattsagramPostService._();

  static SupabaseClient get _client => Supabase.instance.client;
  static const String _table = 'tattsagram_post';

  /// Maps a Realtime / JSON row to [TattsagramPost] (same shape as REST [fetchPosts]).
  static TattsagramPost postFromRealtimeRow(Map<String, dynamic> row) {
    final normalized = Map<String, dynamic>.from(row);
    final id = normalized['id'];
    if (id != null) {
      normalized['id'] = id.toString();
    }
    final created = normalized['created_at'];
    if (created != null && created is! String) {
      normalized['created_at'] = created.toString();
    }
    return _fromRow(normalized);
  }

  static Future<TattsagramPost> createPost({
    required String mediaUrl,
    required TattsagramMediaType mediaType,
    required String artistName,
    String location = '',
    String caption = '',
    String? thumbnailUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User must be authenticated');

    final row = await _client
        .from(_table)
        .insert({
          'user_id': user.id,
          'media_url': mediaUrl,
          'media_type': mediaType.name,
          'artist_name': artistName,
          'location': location,
          'caption': caption,
          'thumbnail_url': thumbnailUrl,
        })
        .select()
        .single();
    return _fromRow(row);
  }

  /// Global shared feed: all posts visible under RLS (see `tattsagram_post` select policy).
  ///
  /// Never filter by `user_id` — every account sees the same ordering; new users see
  /// existing videos. Only [limit]/[offset] paginate the result set.
  static Future<List<TattsagramPost>> fetchPosts({
    int limit = 20,
    int offset = 0,
  }) async {
    final posts = await _client
        .from('tattsagram_post')
        .select()
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    debugPrint(
      'TattsagramPostService.fetchPosts: Fetched posts: ${posts.length} (limit=$limit offset=$offset)',
    );
    return posts.map<TattsagramPost>(_fromRow).toList();
  }

  static TattsagramPost _fromRow(Map<String, dynamic> row) {
    final rawType = (row['media_type'] as String?)?.trim().toLowerCase();
    final mediaType = rawType == 'video'
        ? TattsagramMediaType.video
        : TattsagramMediaType.image;
    final likes = _parseLikesCount(row['likes_count']);
    final mediaUrl = (row['media_url'] as String?) ?? '';
    return TattsagramPost(
      id: row['id'] as String?,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      videoUrl: mediaType == TattsagramMediaType.video && mediaUrl.isNotEmpty
          ? mediaUrl
          : null,
      artistName: (row['artist_name'] as String?)?.trim().isNotEmpty == true
          ? (row['artist_name'] as String)
          : 'Unknown',
      location: (row['location'] as String?) ?? '',
      caption: (row['caption'] as String?) ?? '',
      thumbnailUrl: row['thumbnail_url'] as String?,
      timestamp: DateTime.tryParse((row['created_at'] as String?) ?? '') ??
          DateTime.now(),
      likesCount: likes < 0 ? 0 : likes,
    );
  }

  static int _parseLikesCount(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString()) ?? 0;
  }
}
