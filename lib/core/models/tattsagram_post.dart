/// Media kind for [TattsagramPost] (matches `tattsagram_post.media_type` in Supabase).
enum TattsagramMediaType {
  image,
  video,
}

/// One item in the Tattsagram feed (mock, user upload from live chat, or API).
class TattsagramPost {
  /// Step 2 — optimistic video tile at `posts.insert(0, …)` before storage upload.
  factory TattsagramPost.tempVideoUpload({
    required String id,
    required String localVideo,
  }) {
    return TattsagramPost(
      id: id,
      mediaUrl: '',
      mediaType: TattsagramMediaType.video,
      artistName: 'You',
      location: '',
      caption: '',
      timestamp: DateTime.now(),
      localVideo: localVideo,
      isUploading: true,
      uploadProgress: 0,
      videoUrl: null,
    );
  }

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

    /// Local file path while a video is uploading (feed preview only).
    this.localVideo,
    this.isUploading = false,

    /// In-flight upload fraction in \[0, 1\]. Server-backed posts keep `0` (see [uploadProgressNormalized]).
    this.uploadProgress = 0.0,

    /// Public video URL once on storage; null while only [localVideo] is set.
    this.videoUrl,

    /// When set, [TattsagramPage] removes the pending row with this [id] before adding the server post.
    this.replacesLocalUploadId,
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

  /// Device path for in-progress video upload preview; null once [videoUrl] / [mediaUrl] is set.
  final String? localVideo;

  /// True while the file is still uploading in the background.
  final bool isUploading;

  /// Client-only upload fraction in \[0, 1\]. Updated by the upload pipeline while [isUploading].
  final double uploadProgress;

  /// [uploadProgress] clamped to \[0, 1\].
  double get uploadProgressNormalized => uploadProgress.clamp(0.0, 1.0);

  /// Remote URL for video posts; mirrors [media_url] when loaded from the server.
  final String? videoUrl;

  /// Client temp row id to remove when the real [TattsagramPost] arrives.
  final String? replacesLocalUploadId;

  /// Non-empty when the post has a server-backed URL (dedupe, merge, like key fallback).
  String get canonicalRemoteUrl {
    if (mediaType == TattsagramMediaType.video) {
      final v = videoUrl?.trim() ?? '';
      if (v.isNotEmpty) return v;
      return mediaUrl.trim();
    }
    return mediaUrl.trim();
  }

  /// Supabase-style key access; use `post['likes_count'] ?? 0` for display.
  int? operator [](Object? key) {
    if (key == 'likes_count') {
      final n = likesCount;
      return n < 0 ? 0 : n;
    }
    return null;
  }

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
    String? localVideo,
    bool? isUploading,
    double? uploadProgress,
    String? videoUrl,
    String? replacesLocalUploadId,
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
      localVideo: localVideo ?? this.localVideo,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      videoUrl: videoUrl ?? this.videoUrl,
      replacesLocalUploadId:
          replacesLocalUploadId ?? this.replacesLocalUploadId,
    );
  }
}
