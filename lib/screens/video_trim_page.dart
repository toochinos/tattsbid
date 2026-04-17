import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_trimmer/video_trimmer.dart';

class VideoTrimPage extends StatefulWidget {
  const VideoTrimPage({
    super.key,
    required this.file,
    this.maxDurationSeconds = 15,
  });

  final File file;
  final int maxDurationSeconds;

  @override
  State<VideoTrimPage> createState() => _VideoTrimPageState();
}

class _VideoTrimPageState extends State<VideoTrimPage> {
  final Trimmer _trimmer = Trimmer();
  double _startValue = 0.0;
  double _endValue = 0.0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVideo());
  }

  Future<void> _loadVideo() async {
    await _trimmer.loadVideo(videoFile: widget.file);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveTrimmed() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final completer = Completer<String?>();
    _trimmer.saveTrimmedVideo(
      startValue: _startValue,
      endValue: _endValue,
      onSave: (outputPath) {
        completer.complete(outputPath);
      },
    );
    final path = await completer.future;
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (path == null || path.isEmpty) return;
    Navigator.of(context).pop(File(path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Trim video'),
        actions: [
          TextButton(
            onPressed: _isLoading || _isSaving ? null : _saveTrimmed,
            child: Text(
              _isSaving ? 'Saving...' : 'Done',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: VideoViewer(trimmer: _trimmer)),
                const SizedBox(height: 12),
                TrimViewer(
                  trimmer: _trimmer,
                  viewerHeight: 56,
                  viewerWidth: MediaQuery.sizeOf(context).width,
                  maxVideoLength: Duration(seconds: widget.maxDurationSeconds),
                  onChangeStart: (value) => _startValue = value,
                  onChangeEnd: (value) => _endValue = value,
                  onChangePlaybackState: (value) {
                    if (!mounted) return;
                    setState(() => _isPlaying = value);
                  },
                ),
                const SizedBox(height: 12),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle : Icons.play_circle,
                    color: Colors.white,
                    size: 40,
                  ),
                  onPressed: () async {
                    final playbackState = await _trimmer.videoPlaybackControl(
                      startValue: _startValue,
                      endValue: _endValue,
                    );
                    if (!mounted) return;
                    setState(() => _isPlaying = playbackState);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
