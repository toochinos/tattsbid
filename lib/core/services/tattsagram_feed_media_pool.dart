import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import '../models/tattsagram_post.dart';

/// Owns one fully **file-backed** video decoder (offline-safe after first buffer).
class TattsagramFeedMediaSlot extends ChangeNotifier {
  VideoPlayerController? _controller;
  TattsagramPost? _bound;
  int _generation = 0;
  Future<void>? _ensureFuture;

  VideoPlayerController? get controller => _controller;
  bool get hasInitializedController =>
      _controller != null && _controller!.value.isInitialized;

  bool get isIdle => _ensureFuture == null && _controller == null;

  static bool sameMedia(TattsagramPost a, TattsagramPost b) {
    if (a.mediaType != b.mediaType) return false;
    final la = a.localVideo?.trim() ?? '';
    final lb = b.localVideo?.trim() ?? '';
    if (la.isNotEmpty || lb.isNotEmpty) {
      return la.isNotEmpty && la == lb;
    }
    return a.canonicalRemoteUrl.trim() == b.canonicalRemoteUrl.trim();
  }

  static Future<File?> _resolveLocalVideoFile(TattsagramPost post) async {
    final local = post.localVideo?.trim() ?? '';
    if (local.isEmpty) return null;
    final f = File(local);
    if (await f.exists()) return f;
    return null;
  }

  static Future<File?> _downloadRemoteVideoToCache(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    try {
      return await DefaultCacheManager().getSingleFile(trimmed);
    } catch (e, st) {
      debugPrint(
          'TattsagramFeedMediaSlot._downloadRemoteVideoToCache: $e\n$st');
      return null;
    }
  }

  static Future<File?> _resolvePlayableVideoFile(TattsagramPost post) async {
    final local = await _resolveLocalVideoFile(post);
    if (local != null) return local;

    final url = (post.videoUrl?.trim().isNotEmpty ?? false)
        ? post.videoUrl!.trim()
        : post.mediaUrl.trim();
    return _downloadRemoteVideoToCache(url);
  }

  Future<void> ensure(TattsagramPost post) async {
    if (post.mediaType != TattsagramMediaType.video) return;

    if (_bound != null && !sameMedia(_bound!, post)) {
      await teardown();
    }
    _bound = post;

    if (_controller != null && _controller!.value.isInitialized) {
      return;
    }

    final existing = _ensureFuture;
    if (existing != null) {
      await existing;
      if (_controller != null && _controller!.value.isInitialized) {
        return;
      }
    }

    final work = _ensureImpl(post);
    _ensureFuture = work;
    try {
      await work;
    } finally {
      if (identical(_ensureFuture, work)) {
        _ensureFuture = null;
      }
    }
  }

  Future<void> _ensureImpl(TattsagramPost post) async {
    final gen = ++_generation;
    VideoPlayerController? created;

    try {
      final file = await _resolvePlayableVideoFile(post);
      if (gen != _generation) return;
      if (_bound == null || !sameMedia(_bound!, post)) return;
      if (file == null) {
        notifyListeners();
        return;
      }

      created = VideoPlayerController.file(file);
      _controller = created;
      await created.initialize();
      await created.setLooping(true);
      await created.setVolume(0);

      if (gen != _generation) {
        await created.dispose();
        if (identical(_controller, created)) {
          _controller = null;
        }
        notifyListeners();
        return;
      }
      if (_bound == null || !sameMedia(_bound!, post)) {
        await created.dispose();
        if (identical(_controller, created)) {
          _controller = null;
        }
        notifyListeners();
        return;
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('TattsagramFeedMediaSlot._ensureImpl: $e\n$st');
      final c = created ?? _controller;
      if (c != null) {
        await c.dispose();
      }
      if (identical(_controller, c)) {
        _controller = null;
      }
      notifyListeners();
    }
  }

  Future<void> teardown() async {
    _generation++;
    final c = _controller;
    _controller = null;
    _bound = null;
    if (c != null) {
      try {
        await c.pause();
      } catch (_) {}
      await c.dispose();
    }
    notifyListeners();
  }
}

/// Vertical-feed media cache with bounded controller lifecycle.
///
/// Active window: `N-1, N, N+1, N+2`; preload: `N+3`.
/// Typical initialized controllers: 5 (hard cap 6).
///
/// **When controllers are created:** the first time an index enters this window,
/// [TattsagramFeedMediaSlot.ensure] runs: full-file download via [DefaultCacheManager],
/// then [VideoPlayerController.file]. Controllers are **not** created inside PageView
/// item build; they are warmed from [syncWarmRing] (scroll + layout).
///
/// Controllers are disposed only when far from the anchor (`<= N-4` behind, and
/// similarly far ahead), with delay to avoid rapid churn.
class TattsagramFeedMediaPool {
  TattsagramFeedMediaPool();

  /// Keep one behind in active controller window.
  static const int _lookBehind = 1;

  /// Keep three ahead in active+preload window (`+1,+2,+3`).
  static const int _lookAhead = 3;

  /// Retain nearby controllers to prevent release/recreate loops.
  static const int _retainBehind = 2; // dispose at N-3 and older
  static const int _retainAhead = 3;
  static const int _maxControllers = 5;
  static const Duration _disposeDelay = Duration(seconds: 8);

  final Map<String, TattsagramFeedMediaSlot> _slots = {};
  final Map<String, Timer> _disposeTimers = {};
  final Set<String> _wantedKeys = {};

  static String slotKey(int index, TattsagramPost post) {
    final fp = _fingerprint(post);
    return '$index|$fp';
  }

  static String _fingerprint(TattsagramPost post) {
    final loc = post.localVideo?.trim() ?? '';
    if (loc.isNotEmpty) return 'L:$loc';
    final url = post.canonicalRemoteUrl.trim();
    if (url.isNotEmpty) {
      return '${post.mediaType.name}:$url';
    }
    final id = post.id?.trim() ?? '';
    if (id.isNotEmpty) return 'id:$id';
    return 'empty';
  }

  TattsagramFeedMediaSlot slotFor(int index, TattsagramPost post) {
    final k = slotKey(index, post);
    return _slots.putIfAbsent(k, () => TattsagramFeedMediaSlot());
  }

  /// [committedCenter] tracks settled UI index; [scrollPage] fractional page for early warm.
  void syncWarmRing({
    required List<TattsagramPost> sequence,
    required int committedCenter,
    required BuildContext context,
    double? scrollPage,
  }) {
    if (sequence.isEmpty) return;
    final L = sequence.length;
    final committed = committedCenter.clamp(0, L - 1);

    int warmAnchor = committed;
    if (scrollPage != null) {
      final p = scrollPage.clamp(0.0, L - 1.0);
      // Forward-biased: while N-1 is visible, begin warming N and beyond.
      warmAnchor = (p.floor() + 1).clamp(0, L - 1);
    }

    final wanted = <String>{};
    final retained = <String>{};
    for (var d = -_lookBehind; d <= _lookAhead; d++) {
      final i = warmAnchor + d;
      if (i < 0 || i >= sequence.length) continue;
      final post = sequence[i];
      final k = slotKey(i, post);
      wanted.add(k);
      _cancelDisposeTimer(k);
      _slots.putIfAbsent(k, () => TattsagramFeedMediaSlot());
      unawaited(_precachePostMedia(context, post));
      if (post.mediaType == TattsagramMediaType.video) {
        unawaited(_precacheVideoThumbDisk(post.thumbnailUrl));
      }
    }
    for (var d = -_retainBehind; d <= _retainAhead; d++) {
      final i = warmAnchor + d;
      if (i < 0 || i >= sequence.length) continue;
      retained.add(slotKey(i, sequence[i]));
    }

    unawaited(_ensureWindowInPriorityOrder(sequence, warmAnchor));

    _wantedKeys
      ..clear()
      ..addAll(wanted);

    for (final key in _slots.keys.toList(growable: false)) {
      if (retained.contains(key)) continue;
      _scheduleDispose(key);
    }
    _enforceControllerLimit(warmAnchor);
  }

  /// Current first, then **N+1 → N+2 → N+3**, then trailing.
  Future<void> _ensureWindowInPriorityOrder(
    List<TattsagramPost> sequence,
    int warmAnchor,
  ) async {
    final L = sequence.length;
    final order = <int>[
      warmAnchor,
      for (var d = 1; d <= _lookAhead; d++) warmAnchor + d,
      for (var d = 1; d <= _lookBehind; d++) warmAnchor - d,
    ];
    final seen = <int>{};
    for (final i in order) {
      if (i < 0 || i >= L) continue;
      if (!seen.add(i)) continue;
      final post = sequence[i];
      if (post.mediaType != TattsagramMediaType.video) continue;
      await slotFor(i, post).ensure(post);
    }
  }

  static int? _slotIndex(String key) {
    final sep = key.indexOf('|');
    if (sep <= 0) return null;
    return int.tryParse(key.substring(0, sep));
  }

  void _enforceControllerLimit(int warmAnchor) {
    final initialized = <({String key, int distance})>[];
    for (final entry in _slots.entries) {
      if (!entry.value.hasInitializedController) continue;
      final idx = _slotIndex(entry.key);
      if (idx == null) continue;
      initialized.add((key: entry.key, distance: (idx - warmAnchor).abs()));
    }
    if (initialized.length <= _maxControllers) return;
    initialized.sort((a, b) => b.distance.compareTo(a.distance));
    final overflow = initialized.length - _maxControllers;
    for (var i = 0; i < overflow; i++) {
      final key = initialized[i].key;
      _cancelDisposeTimer(key);
      final slot = _slots[key];
      if (slot != null) {
        unawaited(slot.teardown());
      }
    }
    _evictDistantEmptySlots();
  }

  static Future<void> _precacheVideoThumbDisk(String? thumb) async {
    final u = thumb?.trim() ?? '';
    if (u.isEmpty || !u.startsWith('http')) return;
    try {
      await DefaultCacheManager().getSingleFile(u);
    } catch (e, st) {
      debugPrint('TattsagramFeedMediaPool thumb disk: $e\n$st');
    }
  }

  void _cancelDisposeTimer(String key) {
    _disposeTimers[key]?.cancel();
    _disposeTimers.remove(key);
  }

  void _scheduleDispose(String key) {
    _cancelDisposeTimer(key);
    _disposeTimers[key] = Timer(_disposeDelay, () {
      _disposeTimers.remove(key);
      if (_wantedKeys.contains(key)) return;
      final slot = _slots[key];
      if (slot != null) {
        unawaited(slot.teardown());
      }
      _evictDistantEmptySlots();
    });
  }

  void _evictDistantEmptySlots() {
    if (_slots.length <= 48) return;
    for (final key in _slots.keys.toList(growable: false)) {
      if (_wantedKeys.contains(key)) continue;
      final s = _slots[key];
      if (s != null && s.isIdle) {
        _slots.remove(key);
      }
    }
  }

  static Future<void> _precachePostMedia(
    BuildContext context,
    TattsagramPost post,
  ) async {
    if (!context.mounted) return;
    try {
      if (post.mediaType == TattsagramMediaType.image) {
        final u = post.mediaUrl.trim();
        final uri = Uri.tryParse(u);
        if (uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            u.isNotEmpty) {
          // Precache disabled intentionally.
        }
        return;
      }
      final thumb = post.thumbnailUrl?.trim();
      if (thumb != null && thumb.isNotEmpty && thumb.startsWith('http')) {
        // Precache disabled intentionally.
      }
    } catch (e, st) {
      debugPrint('TattsagramFeedMediaPool precache: $e\n$st');
    }
  }

  Future<void> disposeAll() async {
    for (final t in _disposeTimers.values) {
      t.cancel();
    }
    _disposeTimers.clear();
    _wantedKeys.clear();
    final copy = _slots.values.toList(growable: false);
    _slots.clear();
    for (final s in copy) {
      await s.teardown();
    }
  }
}
