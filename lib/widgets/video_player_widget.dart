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
  });

  final String mediaUrl;
  final Object soundSlotId;
  final ScrollController? scrollController;
  final ValueListenable<bool>? feedPlaybackListenable;

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;

  bool get _feedAllowsPlayback => widget.feedPlaybackListenable?.value ?? true;

  void _onVideoControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _onTapResumeIfFrozen() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (!c.value.isPlaying) {
      c.play();
    }
  }

  void _onScrollRecomputeSound() {
    _applySoundFromLayout();
  }

  void _applySoundFromLayout() {
    if (!mounted) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    if (!_feedAllowsPlayback) {
      TattsagramVideoSoundRegistry.applyFeedPlaybackGate(
        controller: c,
        allow: false,
      );
      return;
    }

    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return;

    final offset = ro.localToGlobal(Offset.zero);
    final top = offset.dy;
    final bottom = top + ro.size.height;
    final tileCenter = top + (bottom - top) / 2;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenCenter = screenHeight / 2;
    final distance = (tileCenter - screenCenter).abs();

    TattsagramVideoSoundRegistry.beginScrollSoundPass();
    TattsagramVideoSoundRegistry.submitSoundCandidate(c, distance);
    TattsagramVideoSoundRegistry.scheduleFinalizeSoundPass();
  }

  void _onFeedPlaybackGateChanged() => _applySoundFromLayout();

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScrollRecomputeSound);
    widget.feedPlaybackListenable?.addListener(_onFeedPlaybackGateChanged);
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        _controller!
          ..setLooping(true)
          ..setVolume(0)
          ..play();
        _controller!.addListener(_onVideoControllerUpdate);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applySoundFromLayout();
        });
        setState(() {});
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applySoundFromLayout();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScrollRecomputeSound);
      widget.scrollController?.addListener(_onScrollRecomputeSound);
    }
    if (oldWidget.feedPlaybackListenable != widget.feedPlaybackListenable) {
      oldWidget.feedPlaybackListenable
          ?.removeListener(_onFeedPlaybackGateChanged);
      widget.feedPlaybackListenable?.addListener(_onFeedPlaybackGateChanged);
    }
    if (oldWidget.mediaUrl != widget.mediaUrl) {
      final oldC = _controller;
      if (oldC != null) {
        oldC.removeListener(_onVideoControllerUpdate);
        TattsagramVideoSoundRegistry.disposeSlot(oldC);
        oldC.dispose();
      }
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl))
        ..initialize().then((_) {
          if (!mounted) return;
          _controller!
            ..setLooping(true)
            ..setVolume(0)
            ..play();
          _controller!.addListener(_onVideoControllerUpdate);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _applySoundFromLayout();
          });
          setState(() {});
        });
    } else if (oldWidget.soundSlotId != widget.soundSlotId) {
      final c = _controller;
      if (c != null) {
        TattsagramVideoSoundRegistry.disposeSlot(c);
      }
      _applySoundFromLayout();
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScrollRecomputeSound);
    widget.feedPlaybackListenable?.removeListener(_onFeedPlaybackGateChanged);
    final c = _controller;
    if (c != null) {
      c.removeListener(_onVideoControllerUpdate);
      TattsagramVideoSoundRegistry.disposeSlot(c);
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      final showPausedHint = !c.value.isPlaying;
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: c.value.size.width,
          height: c.value.size.height,
          child: GestureDetector(
            onTap: _onTapResumeIfFrozen,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                VideoPlayer(c),
                if (showPausedHint)
                  Icon(
                    Icons.play_circle_outline,
                    size: 56,
                    color: Colors.white.withValues(alpha: 0.88),
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 12,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: CircularProgressIndicator(color: Colors.white54),
      ),
    );
  }
}
