import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

/// Feed-only playback optimization.
///
/// If the source exceeds 720x1280 bounds, creates a compressed copy for playback.
/// The original file is never modified or deleted.
class TattsagramFeedVideoOptimizer {
  TattsagramFeedVideoOptimizer._();

  static const int _maxWidth = 720;
  static const int _maxHeight = 1280;

  static Future<String> optimizeLocalPath(String sourcePath) async {
    final src = sourcePath.trim();
    if (src.isEmpty) return sourcePath;

    try {
      final info = await VideoCompress.getMediaInfo(src);
      final width = (info.width ?? 0).round();
      final height = (info.height ?? 0).round();
      if (width <= 0 || height <= 0) return sourcePath;
      if (width <= _maxWidth && height <= _maxHeight) return sourcePath;

      final out = await VideoCompress.compressVideo(
        src,
        quality: VideoQuality.Res1280x720Quality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 30,
      );
      final f = out?.file;
      if (f != null && f.path.isNotEmpty) return f.path;
      final p = out?.path;
      if (p != null && p.isNotEmpty) return p;
      return sourcePath;
    } catch (e, st) {
      debugPrint('TattsagramFeedVideoOptimizer: $e\n$st');
      return sourcePath;
    }
  }
}
