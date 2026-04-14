import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk cache for remote video bytes only — no [VideoPlayerController].
class VideoCacheManager {
  VideoCacheManager._();
  static final VideoCacheManager _instance = VideoCacheManager._();
  factory VideoCacheManager() => _instance;

  static final CacheManager _cache = CacheManager(
    Config(
      'tattsagramVideos',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 200,
    ),
  );

  /// Fire-and-forget download into cache (e.g. next feed item). Never throws to caller.
  void downloadFile(String url) {
    final u = url.trim();
    if (u.isEmpty || !_isHttp(u)) return;
    unawaited(() async {
      try {
        await _cache.getSingleFile(u);
      } catch (e, st) {
        debugPrint('VideoCacheManager.downloadFile: $e\n$st');
      }
    }());
  }

  static bool _isHttp(String u) =>
      u.startsWith('http://') || u.startsWith('https://');
}
