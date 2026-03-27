import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_schema.dart';
import '../models/artist_review.dart';

class ReviewService {
  ReviewService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Newest first.
  static Future<List<ArtistReview>> fetchForArtist(String artistId) async {
    if (artistId.trim().isEmpty) return [];

    final res = await _client
        .from(SupabaseReviews.table)
        .select()
        .eq(SupabaseReviews.artistId, artistId)
        .order(SupabaseReviews.createdAt, ascending: false);

    final out = <ArtistReview>[];
    for (final raw in res as List) {
      final m = raw as Map<String, dynamic>;
      try {
        out.add(ArtistReview.fromSupabaseRow(m));
      } catch (_) {
        // skip bad rows
      }
    }
    return out;
  }

  static double averageRating(List<ArtistReview> reviews) {
    if (reviews.isEmpty) return 0;
    final sum = reviews.fold<int>(0, (a, r) => a + r.rating);
    return sum / reviews.length;
  }

  static Future<ArtistReview?> getMyReviewForArtist(String artistId) async {
    final user = _client.auth.currentUser;
    final aid = artistId.trim();
    if (user == null || aid.isEmpty) return null;

    final row = await _client
        .from(SupabaseReviews.table)
        .select()
        .eq(SupabaseReviews.userId, user.id)
        .eq(SupabaseReviews.artistId, aid)
        .maybeSingle();
    if (row == null) return null;
    return ArtistReview.fromSupabaseRow(row);
  }

  /// Mean rating per artist from `reviews` (artists with no rows are omitted).
  static Future<Map<String, double>> fetchAverageRatingsForArtistIds(
    Iterable<String> artistIds,
  ) async {
    final ids =
        artistIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) return {};

    final res = await _client
        .from(SupabaseReviews.table)
        .select('${SupabaseReviews.artistId}, ${SupabaseReviews.rating}')
        .inFilter(SupabaseReviews.artistId, ids);

    final buckets = <String, List<int>>{};
    for (final raw in res as List) {
      final m = raw as Map<String, dynamic>;
      final aid = m[SupabaseReviews.artistId] as String?;
      if (aid == null || aid.isEmpty) continue;
      final r = m[SupabaseReviews.rating];
      final ri =
          r is int ? r : (r is num ? r.toInt() : int.tryParse('$r') ?? 0);
      if (ri < 1 || ri > 5) continue;
      buckets.putIfAbsent(aid, () => []).add(ri);
    }

    final out = <String, double>{};
    for (final e in buckets.entries) {
      final v = e.value;
      if (v.isEmpty) continue;
      out[e.key] = v.reduce((a, b) => a + b) / v.length;
    }
    return out;
  }

  /// Creates or updates review for [artistId] as signed-in user.
  ///
  /// - if review does not exist: creates and returns [ReviewSubmitResult.created]
  /// - if review exists and [allowEdit] is false: no write, returns [alreadyReviewed]
  /// - if review exists and [allowEdit] is true: updates and returns [updated]
  static Future<ReviewSubmitResult> submitReview({
    required String artistId,
    required int rating,
    required String comment,
    bool allowEdit = true,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to leave a review');
    }
    final aid = artistId.trim();
    if (aid.isEmpty) {
      throw ArgumentError('Artist id cannot be empty');
    }
    final r = rating.clamp(1, 5);
    final c = comment.trim();
    if (c.isEmpty) {
      throw ArgumentError('Comment cannot be empty');
    }

    final existing = await _client
        .from(SupabaseReviews.table)
        .select(SupabaseReviews.id)
        .eq(SupabaseReviews.userId, user.id)
        .eq(SupabaseReviews.artistId, aid)
        .maybeSingle();

    if (existing != null) {
      if (!allowEdit) return ReviewSubmitResult.alreadyReviewed;
      final id = existing[SupabaseReviews.id] as String?;
      if (id == null || id.isEmpty) return ReviewSubmitResult.alreadyReviewed;
      await _client.from(SupabaseReviews.table).update({
        SupabaseReviews.rating: r,
        SupabaseReviews.comment: c,
      }).eq(SupabaseReviews.id, id);
      return ReviewSubmitResult.updated;
    }

    await _client.from(SupabaseReviews.table).insert({
      SupabaseReviews.userId: user.id,
      SupabaseReviews.artistId: aid,
      SupabaseReviews.rating: r,
      SupabaseReviews.comment: c,
    });
    return ReviewSubmitResult.created;
  }
}

enum ReviewSubmitResult {
  created,
  updated,
  alreadyReviewed,
}
