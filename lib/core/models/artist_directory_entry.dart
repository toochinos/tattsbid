import '../config/supabase_schema.dart';
import '../utils/safe_double.dart' show doubleFromJsonNumNullable;

/// Row for the Artists directory list (browse tattoo artists).
///
/// [rating] is optional: maps from `profiles.rating` if the column exists in Supabase.
class ArtistDirectoryEntry {
  const ArtistDirectoryEntry({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.location,
    this.suburb,
    this.city,
    this.country,
    this.rating,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? location;
  final String? suburb;
  final String? city;
  final String? country;

  /// Average rating when stored on profile; null if unavailable.
  final double? rating;

  /// True if any location field is non-empty (structured or legacy [location]).
  bool get hasLocationDisplay {
    bool nz(String? s) => s != null && s.trim().isNotEmpty;
    return nz(suburb) || nz(city) || nz(country) || nz(location);
  }

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
    if (v is String && v.trim().isEmpty) return null;
    return doubleFromJsonNumNullable(v);
  }

  factory ArtistDirectoryEntry.fromSupabaseRow(Map<String, dynamic> m) {
    final id = m[SupabaseProfiles.id] as String?;
    if (id == null || id.isEmpty) {
      throw ArgumentError('Profile row missing id');
    }
    final locRaw = m[SupabaseProfiles.location] as String?;
    final location =
        (locRaw != null && locRaw.trim().isNotEmpty) ? locRaw.trim() : null;
    String? nz(String? raw) {
      final t = raw?.trim();
      return (t != null && t.isNotEmpty) ? t : null;
    }

    return ArtistDirectoryEntry(
      id: id,
      displayName: _nameFromRow(m),
      avatarUrl: m[SupabaseProfiles.avatarUrl] as String?,
      location: location,
      suburb: nz(m[SupabaseProfiles.suburb] as String?),
      city: nz(m[SupabaseProfiles.city] as String?),
      country: nz(m[SupabaseProfiles.country] as String?),
      rating: _ratingFromRow(m),
    );
  }
}
