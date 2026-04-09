import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _capturing = false;
  bool _noCameraDevice = false;
  String? _cameraInitErrorDetail;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _noCameraDevice = true);
        return;
      }
      await _startController(_cameraIndex);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cameraInitErrorDetail = e.toString());
    }
  }

  Future<void> _startController(int index) async {
    final next = CameraController(
      _cameras[index],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await next.initialize();
    final prev = _controller;
    _controller = next;
    _cameraIndex = index;
    await prev?.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _capturing) return;
    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    try {
      await _startController(nextIndex);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cameraSwitchError(e.toString()))),
      );
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final image = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(image.path);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cameraCaptureError(e.toString()))),
      );
      setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_noCameraDevice || _cameraInitErrorDetail != null) {
      final message = _noCameraDevice
          ? l10n.cameraNoDeviceAvailable
          : l10n.cameraInitFailed(_cameraInitErrorDetail!);
      return Scaffold(
        appBar: AppBar(title: Text(l10n.cameraTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cameraTitle)),
      body: CameraPreview(_controller!),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'switch-camera',
            onPressed: _cameras.length > 1 ? _switchCamera : null,
            child: const Icon(Icons.cameraswitch),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'take-photo',
            onPressed: _takePicture,
            child: _capturing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.camera),
          ),
        ],
      ),
    );
  }
}
