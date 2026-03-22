import '../config/supabase_schema.dart';

/// Row for the Artists directory list (browse tattoo artists).
///
/// [rating] is optional: maps from `profiles.rating` if the column exists in Supabase.
class ArtistDirectoryEntry {
  const ArtistDirectoryEntry({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.rating,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;

  /// Average rating when stored on profile; null if unavailable.
  final double? rating;

  /// Lowercase name for A–Z sorting.
  String get sortKey => displayName.trim().toLowerCase();

  static String _nameFromRow(Map<String, dynamic> m) {
    final raw = m[SupabaseProfiles.displayName] as String?;
    if (raw != null && raw.trim().isNotEmpty) return raw.trim();
    return 'Artist';
  }

  static double? _ratingFromRow(Map<String, dynamic> m) {
    final v = m['rating'];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory ArtistDirectoryEntry.fromSupabaseRow(Map<String, dynamic> m) {
    final id = m[SupabaseProfiles.id] as String?;
    if (id == null || id.isEmpty) {
      throw ArgumentError('Profile row missing id');
    }
    return ArtistDirectoryEntry(
      id: id,
      displayName: _nameFromRow(m),
      avatarUrl: m[SupabaseProfiles.avatarUrl] as String?,
      rating: _ratingFromRow(m),
    );
  }
}
