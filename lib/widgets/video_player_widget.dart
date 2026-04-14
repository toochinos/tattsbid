import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/services/tattsagram_video_sound_registry.dart';

/// Full-bleed network video, looping, [BoxFit.cover] (feed tile).
///
/// Sound: once per frame, the tile whose **center** is closest to screen center
/// wins (see [TattsagramVideoSoundRegistry]). [ScrollController] must notify first
/// from [TattsagramPage] so collection resets before submissions.
class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget(
    this.mediaUrl, {
    super.key,
    required this.soundSlotId,
    this.scrollController,
    this.feedPlaybackListenable,
    this.soundMutedListenable,
    this.thumbnailUrl,

    /// When set (e.g. pending Tattsagram upload), plays from disk instead of [mediaUrl].
    this.filePath,

    /// When set, tap / play affordance invokes this instead of toggling playback (e.g. open fullscreen feed).
    this.onSurfaceTap,
  });

  final String mediaUrl;
  final String? thumbnailUrl;

  /// Local file path; takes precedence over [mediaUrl] when non-empty.
  final String? filePath;

  final VoidCallback? onSurfaceTap;
  final Object soundSlotId;
  final ScrollController? scrollController;
  final ValueListenable<bool>? feedPlaybackListenable;
  final ValueListenable<bool>? soundMutedListenable;

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _videoListenerAdded = false;

  bool get _feedAllowsPlayback => widget.feedPlaybackListenable?.value ?? true;
  bool get _userMuted => widget.soundMutedListenable?.value ?? false;

  void _onVideoControllerUpdate() {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      final tier = TattsagramVideoSoundRegistry.playbackTierFor(c);
      if (tier != TattsagramPlaybackTier.center && c.value.isPlaying) {
        unawaited(c.pause());
      }
    }
    if (mounted) setState(() {});
  }

  void _detachVideoListener(VideoPlayerController c) {
    c.removeListener(_onVideoControllerUpdate);
    _videoListenerAdded = false;
  }

  void _attachAndConfigure(VideoPlayerController c) {
    TattsagramVideoSoundRegistry.registerSlot(c);
    c
      ..setLooping(true)
      ..setVolume(0);
    if (!_videoListenerAdded) {
      c.addListener(_onVideoControllerUpdate);
      _videoListenerAdded = true;
    }
  }

  /// On Android (and generally), if you only call [VideoPlayerController.play] while
  /// [VideoPlayerValue.isInitialized] is false, playback usually does not start. We
  /// must [initialize] first, [setState] so [VideoPlayer] is in the tree, then [play].
  Future<void> _onUserPlayOrResume() async {
    final c = _controller;
    if (c == null || !mounted) return;
    try {
      if (!c.value.isInitialized) {
        await c.initialize();
        if (!mounted) return;
        _attachAndConfigure(c);
        setState(() {});
      }
      if (!mounted) return;
      await c.play();
      if (mounted) setState(() {});
    } catch (e, st) {
      debugPrint('VideoPlayerWidget play: $e\n$st');
    }
  }

  Future<void> _applySnapLockedPlayback() async {
    final c = _controller;
    if (!mounted || c == null || !c.value.isInitialized) return;

    if (_feedAllowsPlayback) {
      await c.setVolume(_userMuted ? 0 : 1);
      if (!c.value.isPlaying) {
        await c.play();
      }
    } else {
      await c.setVolume(0);
      if (c.value.isPlaying) {
        await c.pause();
      }
    }
  }

  void _onFeedPlaybackGateChanged() async {
    await _applySnapLockedPlayback();
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (_feedAllowsPlayback) {
      TattsagramVideoSoundRegistry.setSingleActiveController(c);
    } else {
      TattsagramVideoSoundRegistry.applyFeedPlaybackGate(
        controller: c,
        allow: false,
      );
    }
  }

  void _onSoundMuteChanged() => unawaited(_applySnapLockedPlayback());

  VideoPlayerController? _createController() {
    final path = widget.filePath;
    if (path != null && path.isNotEmpty) {
      return VideoPlayerController.file(File(path));
    }
    final url = widget.mediaUrl.trim();
    if (url.isEmpty) return null;
    return VideoPlayerController.networkUrl(Uri.parse(url));
  }

  @override
  void initState() {
    super.initState();
    widget.feedPlaybackListenable?.addListener(_onFeedPlaybackGateChanged);
    widget.soundMutedListenable?.addListener(_onSoundMuteChanged);
    _controller = _createController();
    _controller?.initialize().then((_) async {
      if (!mounted) return;
      final ctrl = _controller;
      if (ctrl == null) return;
      _attachAndConfigure(ctrl);
      await _applySnapLockedPlayback();
      if (_feedAllowsPlayback) {
        TattsagramVideoSoundRegistry.setSingleActiveController(ctrl);
      } else {
        TattsagramVideoSoundRegistry.applyFeedPlaybackGate(
          controller: ctrl,
          allow: false,
        );
      }
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    var playbackSourceChanged = false;
    if (oldWidget.feedPlaybackListenable != widget.feedPlaybackListenable) {
      oldWidget.feedPlaybackListenable
          ?.removeListener(_onFeedPlaybackGateChanged);
      widget.feedPlaybackListenable?.addListener(_onFeedPlaybackGateChanged);
      playbackSourceChanged = true;
    }
    if (oldWidget.soundMutedListenable != widget.soundMutedListenable) {
      oldWidget.soundMutedListenable?.removeListener(_onSoundMuteChanged);
      widget.soundMutedListenable?.addListener(_onSoundMuteChanged);
      playbackSourceChanged = true;
    }
    if (oldWidget.mediaUrl != widget.mediaUrl ||
        oldWidget.filePath != widget.filePath) {
      final oldC = _controller;
      if (oldC != null) {
        _detachVideoListener(oldC);
        TattsagramVideoSoundRegistry.disposeSlot(oldC);
        oldC.dispose();
      }
      _controller = _createController();
      _controller?.initialize().then((_) async {
        if (!mounted) return;
        final ctrl = _controller;
        if (ctrl == null) return;
        _attachAndConfigure(ctrl);
        await _applySnapLockedPlayback();
        if (_feedAllowsPlayback) {
          TattsagramVideoSoundRegistry.setSingleActiveController(ctrl);
        } else {
          TattsagramVideoSoundRegistry.applyFeedPlaybackGate(
            controller: ctrl,
            allow: false,
          );
        }
        if (!mounted) return;
        setState(() {});
      });
      if (_controller == null && mounted) setState(() {});
    } else if (oldWidget.soundSlotId != widget.soundSlotId) {
      final c = _controller;
      if (c != null) {
        TattsagramVideoSoundRegistry.disposeSlot(c);
        if (_feedAllowsPlayback && c.value.isInitialized) {
          TattsagramVideoSoundRegistry.setSingleActiveController(c);
        }
      }
    }
    if (playbackSourceChanged) {
      unawaited(_applySnapLockedPlayback());
      final c = _controller;
      if (c != null && c.value.isInitialized && _feedAllowsPlayback) {
        TattsagramVideoSoundRegistry.setSingleActiveController(c);
      }
    }
  }

  @override
  void dispose() {
    widget.feedPlaybackListenable?.removeListener(_onFeedPlaybackGateChanged);
    widget.soundMutedListenable?.removeListener(_onSoundMuteChanged);
    final c = _controller;
    if (c != null) {
      c.setVolume(0);
      if (c.value.isPlaying) {
        c.pause();
      }
      _detachVideoListener(c);
      TattsagramVideoSoundRegistry.disposeSlot(c);
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    if (c == null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Icon(
            Icons.videocam_off_outlined,
            color: Colors.white.withValues(alpha: 0.54),
            size: 48,
          ),
        ),
      );
    }

    // Android: [VideoPlayer] must sit under [AspectRatio] after init; before init use a spinner only.
    if (!c.value.isInitialized) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white.withValues(alpha: 0.54),
          ),
        ),
      );
    }

    final showPausedHint = !c.value.isPlaying;
    final tier = TattsagramVideoSoundRegistry.playbackTierFor(c);
    final ar = c.value.aspectRatio;
    final aspectRatio = ar > 0 ? ar : 16 / 9;
    final thumb = widget.thumbnailUrl?.trim() ?? '';

    if (tier == TattsagramPlaybackTier.nearCenter && thumb.isNotEmpty) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 1.06),
        duration: const Duration(seconds: 3),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: Image.network(
          thumb,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    if (tier == TattsagramPlaybackTier.far && thumb.isNotEmpty) {
      return Image.network(
        thumb,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: GestureDetector(
          onTap: () {
            if (widget.onSurfaceTap != null) {
              widget.onSurfaceTap!();
            } else {
              unawaited(_onUserPlayOrResume());
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: VideoPlayer(c),
                ),
              ),
              if (showPausedHint)
                IconButton(
                  iconSize: 64,
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.92),
                    shadowColor: Colors.black54,
                  ),
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () async {
                    if (widget.onSurfaceTap != null) {
                      widget.onSurfaceTap!();
                    } else {
                      await _onUserPlayOrResume();
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
