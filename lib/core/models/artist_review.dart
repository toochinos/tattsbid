import '../config/supabase_schema.dart';

/// One row from public.reviews.
class ArtistReview {
  const ArtistReview({
    required this.id,
    required this.userId,
    required this.artistId,
    required this.rating,
    required this.cleanliness,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String artistId;

  /// Overall experience (quality, communication, result), 1–5.
  final int rating;

  /// Hygiene, safety, studio cleanliness, 1–5.
  final int cleanliness;
  final String comment;
  final DateTime createdAt;

  /// Map-style access for list builders (Step 4): `review['rating']`, etc.
  Object? operator [](String key) {
    switch (key) {
      case 'rating':
        return rating;
      case 'cleanliness':
        return cleanliness;
      case 'id':
        return id;
      case 'user_id':
        return userId;
      case 'artist_id':
        return artistId;
      case 'comment':
        return comment;
      case 'created_at':
        return createdAt.toIso8601String();
      default:
        return null;
    }
  }

  /// Step 3 — same as:
  /// `rating: (json['rating'] as num?)?.toDouble() ?? 0.0` (then clamp to 1–5 stars).
  factory ArtistReview.fromJson(Map<String, dynamic> json) =>
      ArtistReview.fromSupabaseRow(json);

  factory ArtistReview.fromSupabaseRow(Map<String, dynamic> m) {
    final id = m[SupabaseReviews.id] as String?;
    if (id == null || id.isEmpty) {
      throw ArgumentError('Review row missing id');
    }
    final userId = m[SupabaseReviews.userId] as String? ?? '';
    final artistId = m[SupabaseReviews.artistId] as String? ?? '';
    // Step 2 / 3 — [num?] + ?.toDouble() ?? 0.0 (handles int / double / null).
    final ratingD = (m[SupabaseReviews.rating] as num?)?.toDouble() ?? 0.0;
    final int rating = ratingD.round().clamp(1, 5).toInt();
    final cRaw = m[SupabaseReviews.cleanliness];
    final int cleanlinessParsed = cRaw == null
        ? rating
        : ((cRaw as num?)?.toDouble() ?? 0.0).round().clamp(1, 5).toInt();
    final comment = (m[SupabaseReviews.comment] as String?)?.trim() ?? '';
    final createdAtRaw = m[SupabaseReviews.createdAt] as String?;
    final createdAt = createdAtRaw != null
        ? DateTime.tryParse(createdAtRaw) ??
            DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.fromMillisecondsSinceEpoch(0);

    return ArtistReview(
      id: id,
      userId: userId,
      artistId: artistId,
      rating: rating,
      cleanliness: cleanlinessParsed,
      comment: comment,
      createdAt: createdAt,
    );
  }
}
