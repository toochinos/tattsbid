/// Media kind for [TattsagramPost] (matches `tattsagram_post.media_type` in Supabase).
enum TattsagramMediaType {
  image,
  video,
}

/// One item in the Tattsagram feed (mock, user upload from live chat, or API).
class TattsagramPost {
  const TattsagramPost({
    this.id,
    required this.mediaUrl,
    this.mediaType = TattsagramMediaType.image,
    required this.artistName,
    required this.location,
    required this.caption,
    required this.timestamp,
    this.thumbnailUrl,
  });

  final String? id;
  final String mediaUrl;
  final TattsagramMediaType mediaType;
  final String artistName;
  final String location;
  final String caption;
  final DateTime timestamp;
  final String? thumbnailUrl;
}
