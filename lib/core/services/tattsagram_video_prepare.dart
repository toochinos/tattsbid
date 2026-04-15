import 'dart:io';

import 'package:video_compress/video_compress.dart';

/// Trim + compress Tattsagram chat uploads before [PhotoService.uploadVideo].
///
/// Camera clips are already capped at 8s by [ImagePicker]; gallery clips longer
/// than 15s are trimmed to the first 15 seconds, then compressed.
class TattsagramVideoPrepare {
  TattsagramVideoPrepare._();

  static const int _galleryMaxDurationMs = 15000;

  /// [VideoCompress] native code expects seconds for [startTime] / [duration].
  static const int _galleryMaxDurationSec = 15;

  /// [fromCamera] true: compress only (picker enforces 8s max).
  /// [fromCamera] false: trim to first 15s if needed, then compress.
  static Future<File> prepareForUpload(
    File original, {
    required bool fromCamera,
  }) async {
    final path = original.path;

    if (fromCamera) {
      final out = await VideoCompress.compressVideo(
        path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
      );
      return _fileFromMediaInfo(out, fallback: original);
    }

    final info = await VideoCompress.getMediaInfo(path);
    final durMs = (info.duration ?? 0).round();
    if (durMs <= 0) {
      final out = await VideoCompress.compressVideo(
        path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
      );
      return _fileFromMediaInfo(out, fallback: original);
    }

    if (durMs > _galleryMaxDurationMs) {
      final out = await VideoCompress.compressVideo(
        path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
        startTime: 0,
        duration: _galleryMaxDurationSec,
      );
      return _fileFromMediaInfo(out, fallback: original);
    }

    final out = await VideoCompress.compressVideo(
      path,
      quality: VideoQuality.LowQuality,
      deleteOrigin: false,
    );
    return _fileFromMediaInfo(out, fallback: original);
  }

  static File _fileFromMediaInfo(MediaInfo? info, {required File fallback}) {
    if (info?.file != null) return info!.file!;
    final p = info?.path;
    if (p != null && p.isNotEmpty) return File(p);
    return fallback;
  }
}
