import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

import '../core/models/tattsagram_post.dart';
import '../core/services/tattsagram_feed_media_pool.dart';
import 'safe_media_renderer.dart';

/// Tattsagram feed video backed by [TattsagramFeedMediaPool] (no per-tap re-init).
class TattsagramPooledVideo extends StatefulWidget {
  const TattsagramPooledVideo({
    super.key,
    required this.feedIndex,
    required this.post,
    required this.pool,
    required this.feedPlaybackListenable,
    required this.soundMutedListenable,
    this.thumbnailUrl,
    this.onSurfaceTap,
  });

  final int feedIndex;
  final TattsagramPost post;
  final TattsagramFeedMediaPool pool;
  final ValueListenable<bool> feedPlaybackListenable;
  final ValueListenable<bool> soundMutedListenable;
  final String? thumbnailUrl;
  final VoidCallback? onSurfaceTap;

  @override
  State<TattsagramPooledVideo> createState() => _TattsagramPooledVideoState();
}

class _TattsagramPooledVideoState extends State<TattsagramPooledVideo> {
  File? _localThumbnailFile;

  @override
  void initState() {
    super.initState();
    widget.feedPlaybackListenable.addListener(_onPlaybackOrMute);
    widget.soundMutedListenable.addListener(_onPlaybackOrMute);
    unawaited(_loadLocalThumbnailIfNeeded());
  }

  @override
  void didUpdateWidget(covariant TattsagramPooledVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feedIndex != widget.feedIndex ||
        !TattsagramFeedMediaSlot.sameMedia(oldWidget.post, widget.post)) {
      _localThumbnailFile = null;
      unawaited(_loadLocalThumbnailIfNeeded());
    }
    if (oldWidget.feedPlaybackListenable != widget.feedPlaybackListenable) {
      oldWidget.feedPlaybackListenable.removeListener(_onPlaybackOrMute);
      widget.feedPlaybackListenable.addListener(_onPlaybackOrMute);
    }
    if (oldWidget.soundMutedListenable != widget.soundMutedListenable) {
      oldWidget.soundMutedListenable.removeListener(_onPlaybackOrMute);
      widget.soundMutedListenable.addListener(_onPlaybackOrMute);
    }
  }

  @override
  void dispose() {
    widget.feedPlaybackListenable.removeListener(_onPlaybackOrMute);
    widget.soundMutedListenable.removeListener(_onPlaybackOrMute);
    super.dispose();
  }

  void _onPlaybackOrMute() => _applyVolumeAndPlayback();

  void _applyVolumeAndPlayback() {
    final slot = widget.pool.slotFor(widget.feedIndex, widget.post);
    final c = slot.controller;
    if (c == null || !c.value.isInitialized) return;
    unawaited(c.setVolume(widget.soundMutedListenable.value ? 0 : 1));
    final allow = widget.feedPlaybackListenable.value;
    if (allow) {
      unawaited(c.play());
    } else {
      unawaited(c.pause());
    }
  }

  Future<void> _loadLocalThumbnailIfNeeded() async {
    final path = widget.post.localVideo?.trim();
    if (path == null || path.isEmpty) return;
    try {
      final bytes = await VideoCompress.getFileThumbnail(path);
      if (!mounted) return;
      if (bytes.path.isNotEmpty) {
        setState(() => _localThumbnailFile = File(bytes.path));
      }
    } catch (_) {}
  }

  Widget _buildThumb(ColorScheme scheme) {
    if (_localThumbnailFile != null) {
      return Image.file(
        _localThumbnailFile!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    final networkThumb = widget.thumbnailUrl?.trim() ?? '';
    if (networkThumb.isNotEmpty) {
      return SafeMediaRenderer(url: networkThumb);
    }
    return const ColoredBox(color: Colors.black);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slot = widget.pool.slotFor(widget.feedIndex, widget.post);
    return AnimatedBuilder(
      animation: slot,
      builder: (context, _) {
        final c = slot.controller;
        if (c != null && c.value.isInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _applyVolumeAndPlayback();
          });
          return FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: widget.onSurfaceTap == null
                  ? VideoPlayer(c)
                  : GestureDetector(
                      onTap: widget.onSurfaceTap,
                      behavior: HitTestBehavior.opaque,
                      child: VideoPlayer(c),
                    ),
            ),
          );
        }
        return _buildThumb(scheme);
      },
    );
  }
}
