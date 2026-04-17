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
    final rows = await _client
        .from('tattsagram_post')
        .select()
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final normalizedRows = rows
        .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    final posts =
        normalizedRows.map<TattsagramPost>(_fromRow).toList(growable: true);

    // Fill missing artist names from profiles by user_id to avoid "Unknown".
    final unresolvedUserIds = <String>{};
    for (var i = 0; i < normalizedRows.length; i++) {
      final currentName = posts[i].artistName.trim().toLowerCase();
      final needsResolve = currentName.isEmpty || currentName == 'unknown';
      if (!needsResolve) continue;
      final userId = normalizedRows[i]['user_id']?.toString().trim() ?? '';
      if (userId.isNotEmpty) {
        unresolvedUserIds.add(userId);
      }
    }
    if (unresolvedUserIds.isNotEmpty) {
      try {
        final profileRows = await _client
            .from('profiles')
            .select('id, username, display_name')
            .inFilter('id', unresolvedUserIds.toList(growable: false));
        final nameByUserId = <String, String>{};
        for (final profile in profileRows) {
          final id = profile['id']?.toString().trim() ?? '';
          if (id.isEmpty) continue;
          final username = profile['username']?.toString().trim() ?? '';
          final displayName = profile['display_name']?.toString().trim() ?? '';
          final resolved = displayName.isNotEmpty
              ? displayName
              : (username.isNotEmpty ? username : '');
          if (resolved.isNotEmpty) {
            nameByUserId[id] = resolved;
          }
        }
        for (var i = 0; i < normalizedRows.length; i++) {
          final currentName = posts[i].artistName.trim().toLowerCase();
          final needsResolve = currentName.isEmpty || currentName == 'unknown';
          if (!needsResolve) continue;
          final userId = normalizedRows[i]['user_id']?.toString().trim() ?? '';
          final resolved = nameByUserId[userId];
          if (resolved != null && resolved.isNotEmpty) {
            posts[i] = posts[i].copyWith(artistName: resolved);
          }
        }
      } catch (_) {
        // Keep current fallback names if profile lookup fails.
      }
    }
    final ids = posts
        .map((p) => p.id)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (ids.isNotEmpty) {
      final likesRows = await _client
          .from('tattsagram_likes')
          .select('post_id, user_id')
          .inFilter('post_id', ids);
      final myUserId = _client.auth.currentUser?.id;
      final likeCounts = <String, int>{};
      final likedByMe = <String>{};
      for (final row in likesRows) {
        final postId = row['post_id']?.toString();
        if (postId == null || postId.isEmpty) continue;
        likeCounts.update(postId, (v) => v + 1, ifAbsent: () => 1);
        if (myUserId != null && row['user_id']?.toString() == myUserId) {
          likedByMe.add(postId);
        }
      }
      for (var i = 0; i < posts.length; i++) {
        final id = posts[i].id;
        if (id == null || id.isEmpty) continue;
        posts[i] = posts[i].copyWith(
          likesCount: likeCounts[id] ?? 0,
          isLikedByMe: likedByMe.contains(id),
        );
      }
    }
    debugPrint(
      'TattsagramPostService.fetchPosts: Fetched posts: ${posts.length} (limit=$limit offset=$offset)',
    );
    return posts;
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
