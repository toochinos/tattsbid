import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/models/tattsagram_post.dart';

class FullScreenViewer extends StatefulWidget {
  const FullScreenViewer({super.key, required this.post});

  final dynamic post;

  @override
  State<FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<FullScreenViewer> {
  VideoPlayerController? _controller;

  TattsagramPost? get _post =>
      widget.post is TattsagramPost ? widget.post as TattsagramPost : null;

  bool get _isVideo => _post?.mediaType == TattsagramMediaType.video;

  String get _mediaUrl {
    final post = _post;
    if (post == null) return '';
    if (post.mediaType == TattsagramMediaType.video) {
      final videoUrl = post.videoUrl?.trim() ?? '';
      if (videoUrl.isNotEmpty) return videoUrl;
    }
    return post.mediaUrl.trim();
  }

  @override
  void initState() {
    super.initState();
    if (_isVideo && _mediaUrl.isNotEmpty) {
      _initVideoPlayer();
    }
  }

  Future<void> _initVideoPlayer() async {
    final mediaUrl = _mediaUrl;
    final uri = Uri.tryParse(mediaUrl);
    if (uri == null) return;
    final controller = (uri.scheme == 'file')
        ? VideoPlayerController.file(File(uri.toFilePath()))
        : VideoPlayerController.networkUrl(uri);
    _controller = controller;
    await controller.initialize();
    if (!mounted || _controller != controller) return;
    await controller.setLooping(true);
    await controller.play();
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaUrl = _mediaUrl;
    final mediaUri = Uri.tryParse(mediaUrl);
    final isRemote = mediaUri != null &&
        (mediaUri.scheme == 'http' || mediaUri.scheme == 'https');
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: _isVideo
              ? (_controller != null && _controller!.value.isInitialized)
                  ? FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    )
                  : const CircularProgressIndicator()
              : (isRemote
                  ? Image.network(mediaUrl, fit: BoxFit.contain)
                  : Image.file(
                      File(mediaUri?.scheme == 'file'
                          ? mediaUri!.toFilePath()
                          : mediaUrl),
                      fit: BoxFit.contain,
                    )),
        ),
      ),
    );
  }
}
