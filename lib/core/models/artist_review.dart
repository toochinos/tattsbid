import '../config/supabase_schema.dart';

/// One row from public.reviews.
class ArtistReview {
  const ArtistReview({
    required this.id,
    required this.userId,
    required this.artistId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String artistId;
  final int rating;
  final String comment;
  final DateTime createdAt;

  factory ArtistReview.fromSupabaseRow(Map<String, dynamic> m) {
    final id = m[SupabaseReviews.id] as String?;
    if (id == null || id.isEmpty) {
      throw ArgumentError('Review row missing id');
    }
    final userId = m[SupabaseReviews.userId] as String? ?? '';
    final artistId = m[SupabaseReviews.artistId] as String? ?? '';
    final r = m[SupabaseReviews.rating];
    final rating =
        r is int ? r : (r is num ? r.toInt() : int.tryParse('$r') ?? 0);
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
      rating: rating.clamp(1, 5),
      comment: comment,
      createdAt: createdAt,
    );
  }
}
