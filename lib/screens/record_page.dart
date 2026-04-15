import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';

import '../core/services/photo_service.dart';

class RecordPageResult {
  const RecordPageResult({required this.videoUrl});

  final String videoUrl;
}

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  static const int _maxVideoDurationSeconds = 10;
  static const int _maxPreferredUploadSizeBytes = 5 * 1024 * 1024;
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _recording = false;
  bool _uploading = false;
  double _uploadProgress = 0.0;
  double _uploadProgressTarget = 0.0;
  Timer? _uploadProgressTicker;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (!mounted) return;
        setState(() => _initError = 'No camera available');
        return;
      }
      await _startController(_cameraIndex);
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = e.toString());
    }
  }

  Future<void> _startController(int index) async {
    final next = CameraController(
      _cameras[index],
      ResolutionPreset.medium,
      enableAudio: true,
    );
    await next.initialize();
    final prev = _controller;
    _controller = next;
    _cameraIndex = index;
    await prev?.dispose();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _startRecording() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _recording ||
        _uploading) {
      return;
    }
    try {
      await controller.startVideoRecording();
      if (!mounted) return;
      setState(() => _recording = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start recording: $e')),
      );
    }
  }

  Future<void> _stopRecordingAndUpload() async {
    final controller = _controller;
    if (controller == null || !_recording || _uploading) return;
    XFile recorded;
    try {
      recorded = await controller.stopVideoRecording();
    } catch (e) {
      if (!mounted) return;
      setState(() => _recording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not stop recording: $e')),
      );
      return;
    }

    final info = await VideoCompress.getMediaInfo(recorded.path);
    final durationMs = info.duration;
    if (durationMs != null && durationMs > _maxVideoDurationSeconds * 1000) {
      if (!mounted) return;
      setState(() => _recording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video must be 15 seconds or less')),
      );
      return;
    }

    await controller.dispose();
    _controller = null;
    if (!mounted) return;
    setState(() {
      _recording = false;
      _uploading = true;
      _uploadProgress = 0.0;
      _uploadProgressTarget = 0.0;
    });
    _startUploadProgressTicker();

    try {
      final compressed = await VideoCompress.compressVideo(
        recorded.path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
      );
      var uploadFile = compressed?.file;
      if (uploadFile == null) {
        throw Exception('Video compression failed');
      }
      if (uploadFile.lengthSync() > _maxPreferredUploadSizeBytes) {
        final lower = await VideoCompress.compressVideo(
          recorded.path,
          quality: VideoQuality.LowQuality,
          deleteOrigin: false,
        );
        final lowerOut = lower?.file;
        if (lowerOut != null) {
          uploadFile = lowerOut;
        }
      }
      print('FINAL VIDEO SIZE MB: ${uploadFile.lengthSync() / 1024 / 1024}');
      if (uploadFile.lengthSync() > 5 * 1024 * 1024) {
        throw Exception('Video too large (>5MB)');
      }
      final url = await PhotoService.uploadVideo(
        uploadFile,
        onUploadProgress: (p) {
          if (!mounted) return;
          _setUploadProgressTarget(p);
        },
      );
      if (!mounted) return;
      _setUploadProgressTarget(1.0);
      await _drainUploadProgressToTarget();
      Navigator.of(context).pop(RecordPageResult(videoUrl: url));
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      _stopUploadProgressTicker();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video upload failed: $e')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _stopUploadProgressTicker();
    _controller?.dispose();
    super.dispose();
  }

  void _setUploadProgressTarget(double value) {
    final next = value.clamp(0.0, 1.0);
    if (next <= _uploadProgressTarget) return;
    _uploadProgressTarget = next;
  }

  void _startUploadProgressTicker() {
    _uploadProgressTicker?.cancel();
    _uploadProgressTicker =
        Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted || !_uploading) return;
      final currentPercent = (_uploadProgress * 100).round();
      final targetPercent = (_uploadProgressTarget * 100).round();
      if (currentPercent >= targetPercent) return;
      final nextPercent = (currentPercent + 1).clamp(0, 100);
      setState(() => _uploadProgress = nextPercent / 100.0);
    });
  }

  Future<void> _drainUploadProgressToTarget() async {
    final start = DateTime.now();
    while (mounted && _uploadProgress < _uploadProgressTarget) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (DateTime.now().difference(start).inMilliseconds > 1200) {
        break;
      }
    }
  }

  void _stopUploadProgressTicker() {
    _uploadProgressTicker?.cancel();
    _uploadProgressTicker = null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(),
      body: _uploading
          ? Center(
              child: Text(
                'Uploading... ${(_uploadProgress * 100).round()}%',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            )
          : (_initError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_initError!, textAlign: TextAlign.center),
                  ),
                )
              : (controller == null || !controller.value.isInitialized)
                  ? const Center(child: CircularProgressIndicator())
                  : CameraPreview(controller)),
      floatingActionButton: _uploading
          ? null
          : FloatingActionButton(
              onPressed: _recording ? _stopRecordingAndUpload : _startRecording,
              child: Icon(_recording ? Icons.stop : Icons.videocam),
            ),
    );
  }
}
