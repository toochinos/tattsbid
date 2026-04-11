import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tattsagram_post.dart';

class TattsagramPostService {
  TattsagramPostService._();

  static SupabaseClient get _client => Supabase.instance.client;
  static const String _table = 'tattsagram_post';

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

  static Future<List<TattsagramPost>> fetchPosts({
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _client
        .from(_table)
        .select()
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map<TattsagramPost>(_fromRow).toList();
  }

  static TattsagramPost _fromRow(Map<String, dynamic> row) {
    final rawType = (row['media_type'] as String?)?.trim().toLowerCase();
    final mediaType = rawType == 'video'
        ? TattsagramMediaType.video
        : TattsagramMediaType.image;
    return TattsagramPost(
      id: row['id'] as String?,
      mediaUrl: (row['media_url'] as String?) ?? '',
      mediaType: mediaType,
      artistName: (row['artist_name'] as String?)?.trim().isNotEmpty == true
          ? (row['artist_name'] as String)
          : 'Unknown',
      location: (row['location'] as String?) ?? '',
      caption: (row['caption'] as String?) ?? '',
      thumbnailUrl: row['thumbnail_url'] as String?,
      timestamp: DateTime.tryParse((row['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
