import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:video_player/video_player.dart';

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
  bool _isVisible = false;
  bool _isInitialized = false;
  int _initEpoch = 0;
  File? _localThumbnailFile;

  bool get _feedAllowsPlayback => widget.feedPlaybackListenable?.value ?? true;
  bool get _userMuted => widget.soundMutedListenable?.value ?? false;

  VideoPlayerController? _createController() {
    final path = widget.filePath;
    if (path != null && path.isNotEmpty) {
      return VideoPlayerController.file(File(path));
    }
    return null;
  }

  Future<void> _initVideo() async {
    if (_controller != null || !_feedAllowsPlayback) return;
    final created = _createController();
    if (created == null) return;
    _controller = created;
    final epoch = ++_initEpoch;
    try {
      await created.initialize();
      if (!mounted || _controller != created || epoch != _initEpoch) return;
      await created.setLooping(true);
      await created.setVolume(_userMuted ? 0 : 1);
      setState(() {
        _isInitialized = true;
      });
      // Start playback as soon as initialization completes.
      await created.play();
    } catch (e, st) {
      debugPrint('VideoPlayerWidget init: $e\n$st');
      if (!mounted) return;
      _disposeVideo();
    }
  }

  void _disposeVideo() {
    final c = _controller;
    _controller = null;
    _isInitialized = false;
    if (c == null) return;
    unawaited(c.pause());
    c.dispose();
  }

  void _onFeedPlaybackGateChanged() {
    final c = _controller;
    if (!_feedAllowsPlayback) {
      c?.pause();
      _disposeVideo();
      if (mounted) setState(() {});
      return;
    }
    if (_isVisible) {
      unawaited(_initVideo());
      c?.play();
    }
  }

  void _onSoundMuteChanged() {
    final c = _controller;
    if (c == null || !_isInitialized) return;
    unawaited(c.setVolume(_userMuted ? 0 : 1));
  }

  @override
  void initState() {
    super.initState();
    widget.feedPlaybackListenable?.addListener(_onFeedPlaybackGateChanged);
    widget.soundMutedListenable?.addListener(_onSoundMuteChanged);
    unawaited(_loadLocalThumbnailIfNeeded());
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feedPlaybackListenable != widget.feedPlaybackListenable) {
      oldWidget.feedPlaybackListenable
          ?.removeListener(_onFeedPlaybackGateChanged);
      widget.feedPlaybackListenable?.addListener(_onFeedPlaybackGateChanged);
    }
    if (oldWidget.soundMutedListenable != widget.soundMutedListenable) {
      oldWidget.soundMutedListenable?.removeListener(_onSoundMuteChanged);
      widget.soundMutedListenable?.addListener(_onSoundMuteChanged);
    }
    if (oldWidget.mediaUrl != widget.mediaUrl ||
        oldWidget.filePath != widget.filePath) {
      _disposeVideo();
      _localThumbnailFile = null;
      unawaited(_loadLocalThumbnailIfNeeded());
      if (_isVisible && _feedAllowsPlayback) {
        unawaited(_initVideo());
      } else if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    widget.feedPlaybackListenable?.removeListener(_onFeedPlaybackGateChanged);
    widget.soundMutedListenable?.removeListener(_onSoundMuteChanged);
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final networkThumb = widget.thumbnailUrl?.trim() ?? '';
    return VisibilityDetector(
      key: Key(widget.filePath?.isNotEmpty == true
          ? widget.filePath!
          : widget.mediaUrl),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.6) {
          _isVisible = true;
          unawaited(_initVideo());
          _controller?.play();
        } else {
          _isVisible = false;
          _controller?.pause();
          _disposeVideo();
          if (mounted) setState(() {});
        }
      },
      child: _isInitialized && _controller != null
          ? AspectRatio(
              aspectRatio: _controller!.value.aspectRatio > 0
                  ? _controller!.value.aspectRatio
                  : 16 / 9,
              child: GestureDetector(
                onTap: () {
                  if (widget.onSurfaceTap != null) {
                    widget.onSurfaceTap!();
                  } else {
                    _controller!.play();
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: VideoPlayer(_controller!),
              ),
            )
          : (widget.mediaUrl.trim().isNotEmpty && _feedAllowsPlayback)
              ? SmartVideoPlayer(videoUrl: widget.mediaUrl)
              : _buildLoadingPreview(networkThumb),
    );
  }

  Widget _buildLoadingPreview(String networkThumb) {
    if (_localThumbnailFile != null) {
      return Image.file(
        _localThumbnailFile!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    if (networkThumb.isNotEmpty) {
      return Image.network(
        networkThumb,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return Container(color: Colors.black);
  }

  Future<void> _loadLocalThumbnailIfNeeded() async {
    final path = widget.filePath;
    if (path == null || path.trim().isEmpty) return;
    try {
      final bytes = await VideoCompress.getFileThumbnail(path);
      if (!mounted) return;
      if (bytes.path.isNotEmpty) {
        setState(() => _localThumbnailFile = bytes);
      }
    } catch (_) {
      // Best-effort preview only.
    }
  }
}

class SmartVideoPlayer extends StatefulWidget {
  const SmartVideoPlayer({super.key, required this.videoUrl});

  final String videoUrl;

  @override
  State<SmartVideoPlayer> createState() => _SmartVideoPlayerState();
}

class _SmartVideoPlayerState extends State<SmartVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  int _initEpoch = 0;

  Future<void> _initVideo() async {
    if (_controller != null) return;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    _controller = controller;
    final epoch = ++_initEpoch;
    await controller.initialize();
    if (!mounted || _controller != controller || epoch != _initEpoch) return;
    await controller.setLooping(true);
    await controller.setVolume(1.0);
    setState(() {
      _isInitialized = true;
    });
    await controller.play();
  }

  void _disposeVideo() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.6) {
          unawaited(_initVideo());
          _controller?.play();
        } else {
          _controller?.pause();
          _disposeVideo();
          if (mounted) setState(() {});
        }
      },
      child: _isInitialized && _controller != null
          ? AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            )
          : Container(color: Colors.black),
    );
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }
}
