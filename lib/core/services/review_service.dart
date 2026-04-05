import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_schema.dart';
import '../utils/safe_double.dart' show doubleFromJsonNum;
import '../utils/supabase_list.dart';
import '../models/artist_review.dart';

/// Mean **Rating** and **Cleanliness** for one artist (separate; never merged).
class ArtistDualRatingAverages {
  const ArtistDualRatingAverages({
    required this.experienceMean,
    required this.cleanlinessMean,
  });

  final double experienceMean;
  final double cleanlinessMean;
}

class ReviewService {
  ReviewService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// One [ArtistReview] per [ArtistReview.userId] (newest [createdAt] wins).
  static List<ArtistReview> _dedupeReviewsNewestPerUser(
    List<ArtistReview> rows,
  ) {
    final byUser = <String, ArtistReview>{};
    for (final r in rows) {
      final prev = byUser[r.userId];
      if (prev == null || r.createdAt.isAfter(prev.createdAt)) {
        byUser[r.userId] = r;
      }
    }
    final list = byUser.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Newest first.
  static Future<List<ArtistReview>> fetchForArtist(String artistId) async {
    if (artistId.trim().isEmpty) return [];

    final res = await _client
        .from(SupabaseReviews.table)
        .select()
        .eq(SupabaseReviews.artistId, artistId)
        .order(SupabaseReviews.createdAt, ascending: false);

    final out = <ArtistReview>[];
    for (final m in mapListFrom(res)) {
      try {
        out.add(ArtistReview.fromSupabaseRow(m));
      } catch (_) {
        // skip bad rows
      }
    }
    return _dedupeReviewsNewestPerUser(out);
  }

  /// Mean overall experience (1–5 stars), or `0` if empty.
  static double averageExperience(List<ArtistReview> reviews) {
    if (reviews.isEmpty) return 0;
    final sum = reviews.fold<int>(0, (a, r) => a + r.rating);
    return sum / reviews.length;
  }

  /// Mean cleanliness (1–5 stars), or `0` if empty.
  static double averageCleanliness(List<ArtistReview> reviews) {
    if (reviews.isEmpty) return 0;
    final sum = reviews.fold<int>(0, (a, r) => a + r.cleanliness);
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

  /// Per-artist means for **rating** and **cleanliness** (no combined score).
  static Future<Map<String, ArtistDualRatingAverages>>
      fetchDualAveragesForArtistIds(
    Iterable<String> artistIds,
  ) async {
    final ids =
        artistIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) return {};

    final res = await _client
        .from(SupabaseReviews.table)
        .select(
          '${SupabaseReviews.artistId}, ${SupabaseReviews.rating}, ${SupabaseReviews.cleanliness}',
        )
        .inFilter(SupabaseReviews.artistId, ids);

    final expBuckets = <String, List<int>>{};
    final cleanBuckets = <String, List<int>>{};
    for (final m in mapListFrom(res)) {
      final aid = m[SupabaseReviews.artistId] as String?;
      if (aid == null || aid.isEmpty) continue;
      final r = m[SupabaseReviews.rating];
      final ri = doubleFromJsonNum(r).round();
      if (ri >= 1 && ri <= 5) {
        expBuckets.putIfAbsent(aid, () => []).add(ri);
      }
      final c = m[SupabaseReviews.cleanliness];
      final ci = doubleFromJsonNum(c).round();
      if (ci >= 1 && ci <= 5) {
        cleanBuckets.putIfAbsent(aid, () => []).add(ci);
      }
    }

    final keys = {...expBuckets.keys, ...cleanBuckets.keys};
    final out = <String, ArtistDualRatingAverages>{};
    for (final k in keys) {
      final ev = expBuckets[k];
      final cv = cleanBuckets[k];
      if ((ev == null || ev.isEmpty) && (cv == null || cv.isEmpty)) continue;
      final eMean = ev == null || ev.isEmpty
          ? 0.0
          : ev.reduce((a, b) => a + b) / ev.length;
      final cMean = cv == null || cv.isEmpty
          ? 0.0
          : cv.reduce((a, b) => a + b) / cv.length;
      out[k] = ArtistDualRatingAverages(
        experienceMean: eMean,
        cleanlinessMean: cMean,
      );
    }
    return out;
  }

  /// Creates or updates review for [artistId] as signed-in user.
  static Future<ReviewSubmitResult> submitReview({
    required String artistId,
    required int rating,
    required int cleanliness,
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
    final cl = cleanliness.clamp(1, 5);
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

    if (existing != null && !allowEdit) {
      return ReviewSubmitResult.alreadyReviewed;
    }

    // Single row per (user_id, artist_id): DB UNIQUE + upsert avoids race duplicates.
    final wasUpdate = existing != null;
    await _client.from(SupabaseReviews.table).upsert(
          {
            SupabaseReviews.userId: user.id,
            SupabaseReviews.artistId: aid,
            SupabaseReviews.rating: r,
            SupabaseReviews.cleanliness: cl,
            SupabaseReviews.comment: c,
          },
          onConflict: '${SupabaseReviews.userId},${SupabaseReviews.artistId}',
        );
    return wasUpdate ? ReviewSubmitResult.updated : ReviewSubmitResult.created;
  }
}

enum ReviewSubmitResult {
  created,
  updated,
  alreadyReviewed,
}
