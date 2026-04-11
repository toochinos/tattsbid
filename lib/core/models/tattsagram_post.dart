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
    this.likesCount = 0,
    this.isLikedByMe = false,
  });

  final String? id;
  final String mediaUrl;
  final TattsagramMediaType mediaType;
  final String artistName;
  final String location;
  final String caption;
  final DateTime timestamp;
  final String? thumbnailUrl;

  /// Weight in ranked pool is [likesCount] + 1.
  final int likesCount;

  final bool isLikedByMe;

  TattsagramPost copyWith({
    String? id,
    String? mediaUrl,
    TattsagramMediaType? mediaType,
    String? artistName,
    String? location,
    String? caption,
    DateTime? timestamp,
    String? thumbnailUrl,
    int? likesCount,
    bool? isLikedByMe,
  }) {
    return TattsagramPost(
      id: id ?? this.id,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      artistName: artistName ?? this.artistName,
      location: location ?? this.location,
      caption: caption ?? this.caption,
      timestamp: timestamp ?? this.timestamp,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      likesCount: likesCount ?? this.likesCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }
}
