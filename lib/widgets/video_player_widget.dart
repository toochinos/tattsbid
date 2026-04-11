import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/services/tattsagram_video_sound_registry.dart';

/// Full-bleed network video, looping, [BoxFit.cover] (feed tile).
///
/// Sound: tile straddles [MediaQuery.size.height / 2]. [ScrollController] listener
/// runs an immediate layout read each scroll update (no debounce, no visibility %).
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

  void _onScrollRecomputeSound() {
    _applyCenterLineNow();
  }

  /// Synchronous center-line check (intended to run from [ScrollController] listener).
  void _applyCenterLineNow() {
    if (!mounted) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return;

    final offset = ro.localToGlobal(Offset.zero);
    final top = offset.dy;
    final bottom = top + ro.size.height;
    final center = MediaQuery.sizeOf(context).height / 2;

    final straddles = top <= center && bottom >= center;

    TattsagramVideoSoundRegistry.syncFeedAndCenterLine(
      controller: c,
      straddlesCenter: straddles,
      feedPlaybackAllowed: _feedAllowsPlayback,
    );
  }

  void _onFeedPlaybackGateChanged() => _applyCenterLineNow();

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
        // One post-frame read so layout exists before any scroll event.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applyCenterLineNow();
        });
        setState(() {});
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyCenterLineNow();
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _applyCenterLineNow();
          });
          setState(() {});
        });
    } else if (oldWidget.soundSlotId != widget.soundSlotId) {
      final c = _controller;
      if (c != null) {
        TattsagramVideoSoundRegistry.disposeSlot(c);
      }
      _applyCenterLineNow();
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScrollRecomputeSound);
    widget.feedPlaybackListenable?.removeListener(_onFeedPlaybackGateChanged);
    final c = _controller;
    if (c != null) {
      TattsagramVideoSoundRegistry.disposeSlot(c);
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: c.value.size.width,
          height: c.value.size.height,
          child: VideoPlayer(c),
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
