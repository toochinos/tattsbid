import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/models/tattsagram_post.dart';
import '../core/services/live_messages_service.dart';
import '../core/services/profile_service.dart';
import '../core/services/live_online_service.dart';
import '../core/services/photo_service.dart';
import '../core/services/tattsagram_video_prepare.dart';
import '../l10n/app_localizations.dart';

enum _TattsagramPickKind {
  cameraPhoto,
  galleryPhoto,
  cameraVideo,
  galleryVideo,
}

/// Slides in from the left over the feed. The message field slides in from the right
/// beside a fixed camera on the left; dismissing collapses the panel and slides the
/// field away while the camera stays. Tap outside (peek) to fully close.
class TattsagramChatOverlay extends StatefulWidget {
  const TattsagramChatOverlay({
    super.key,
    required this.isOpen,
    required this.onClose,
    this.animationDuration = const Duration(milliseconds: 820),
    this.onPhotoPostedToFeed,
    this.showComposerBack = false,
    this.onComposerBack,
  });

  final bool isOpen;
  final VoidCallback onClose;
  final Duration animationDuration;

  /// After a successful storage upload, adds the post to the Tattsagram scroll feed.
  final void Function(TattsagramPost post)? onPhotoPostedToFeed;

  /// Circular back control to the right of the message field (e.g. leave Tattsagram).
  final bool showComposerBack;
  final VoidCallback? onComposerBack;

  @override
  State<TattsagramChatOverlay> createState() => _TattsagramChatOverlayState();
}

class _TattsagramChatOverlayState extends State<TattsagramChatOverlay>
    with SingleTickerProviderStateMixin {
  late final Stream<List<Map<String, dynamic>>> _liveMessagesStream;
  late final Stream<int> _onlineUsersStream;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();

  /// When [widget.isOpen] is true: full slide panel + composer vs peek camera only.
  bool _panelExpanded = true;

  late final AnimationController _panelSlideController;
  late final Animation<Offset> _composerSlide;

  /// Shown immediately on send; removed when the same row appears from [liveChatStream].
  final List<Map<String, dynamic>> _pendingEcho = [];
  int _echoSeq = 0;

  @override
  void initState() {
    super.initState();
    _liveMessagesStream = LiveMessagesService.liveChatStream();
    _onlineUsersStream = LiveOnlineService.onlineUsers();
    final initiallyVisible = widget.isOpen && _panelExpanded;
    _panelSlideController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: initiallyVisible ? 1.0 : 0.0,
    );
    _composerSlide = Tween<Offset>(
      begin: const Offset(1.08, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _panelSlideController,
        curve: Curves.easeInOutQuart,
      ),
    );
  }

  @override
  void didUpdateWidget(TattsagramChatOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animationDuration != oldWidget.animationDuration) {
      _panelSlideController.duration = widget.animationDuration;
    }
    if (widget.isOpen && !oldWidget.isOpen) {
      _panelExpanded = true;
      _panelSlideController.forward();
    } else if (!widget.isOpen && oldWidget.isOpen) {
      _panelSlideController.reverse();
    }
  }

  @override
  void dispose() {
    _panelSlideController.dispose();
    _messageScrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _scrollMessagesToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messageScrollController.hasClients) return;
      final max = _messageScrollController.position.maxScrollExtent;
      _messageScrollController.animateTo(
        max,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _formatTime(BuildContext context, DateTime t) {
    final local = t.toLocal();
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: false,
    );
    return time;
  }

  DateTime _messageTime(Map<String, dynamic> msg) {
    final raw = msg['created_at'];
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }
    return DateTime.now();
  }

  bool _echoMatchesServer(Map<String, dynamic> echo, Map<String, dynamic> row) {
    return (echo['username']?.toString() ?? '') ==
            (row['username']?.toString() ?? '') &&
        (echo['message']?.toString() ?? '') ==
            (row['message']?.toString() ?? '');
  }

  Future<void> _submitLiveMessage(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;

    final username = await ProfileService.resolveLiveDisplayName();
    if (!mounted) return;

    final echoId = ++_echoSeq;
    final echo = <String, dynamic>{
      '_echoId': echoId,
      'username': username,
      'message': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    setState(() {
      _pendingEcho.add(echo);
      _inputController.clear();
    });
    _scrollMessagesToBottom();

    try {
      await LiveMessagesService.sendLiveMessage(text, username: username);
    } catch (e, st) {
      debugPrint('Live message send failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _pendingEcho.removeWhere((p) => p['_echoId'] == echoId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send message')),
      );
      return;
    }

    if (!mounted) return;
    _scrollMessagesToBottom();
  }

  Future<_TattsagramPickKind?> _showTattsagramPickSheet() {
    final scheme = Theme.of(context).colorScheme;
    return showModalBottomSheet<_TattsagramPickKind>(
      context: context,
      backgroundColor: Colors.white,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final accent = scheme.primary;
        final titleStyle = TextStyle(
          color: accent,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt, color: accent),
                  title: Text('Take photo', style: titleStyle),
                  onTap: () => Navigator.of(sheetContext)
                      .pop(_TattsagramPickKind.cameraPhoto),
                ),
                ListTile(
                  leading: Icon(Icons.photo_library_outlined, color: accent),
                  title: Text('Photo from gallery', style: titleStyle),
                  onTap: () => Navigator.of(sheetContext)
                      .pop(_TattsagramPickKind.galleryPhoto),
                ),
                ListTile(
                  leading: Icon(Icons.videocam, color: accent),
                  title: Text('Record video', style: titleStyle),
                  onTap: () => Navigator.of(sheetContext)
                      .pop(_TattsagramPickKind.cameraVideo),
                ),
                ListTile(
                  leading: Icon(Icons.video_library_outlined, color: accent),
                  title: Text('Video from gallery', style: titleStyle),
                  onTap: () => Navigator.of(sheetContext)
                      .pop(_TattsagramPickKind.galleryVideo),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCamera() async {
    if (!mounted) return;
    final kind = await _showTattsagramPickSheet();
    if (!mounted || kind == null) return;

    final needsCamera = kind == _TattsagramPickKind.cameraPhoto ||
        kind == _TattsagramPickKind.cameraVideo;
    if (needsCamera) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileCameraPermissionRequired)),
        );
        return;
      }
    }
    if (kind == _TattsagramPickKind.cameraVideo) {
      await Permission.microphone.request();
    }

    if (kind == _TattsagramPickKind.cameraVideo) {
      await _pickVideo(ImageSource.camera);
      return;
    }
    if (kind == _TattsagramPickKind.galleryVideo) {
      await _pickVideo(ImageSource.gallery);
      return;
    }

    final ImagePicker picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(
        source: kind == _TattsagramPickKind.cameraPhoto
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? e.toString())),
      );
      return;
    }
    if (!mounted || file == null) return;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.tattsagramUploadingPhoto)),
    );

    try {
      final url = await PhotoService.uploadPhoto(File(file.path));
      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      final profile = await ProfileService.getCurrentProfile();
      final displayName = profile?.displayNameOrEmail.trim();
      final artistName =
          (displayName != null && displayName.isNotEmpty) ? displayName : 'You';

      final post = TattsagramPost(
        mediaUrl: url,
        mediaType: TattsagramMediaType.image,
        artistName: artistName,
        location: '',
        caption: '',
        timestamp: DateTime.now(),
      );
      widget.onPhotoPostedToFeed?.call(post);

      if (!mounted) return;
      try {
        await LiveMessagesService.sendLiveMessage(
            l10n.tattsagramPhotoSharedInChat);
      } catch (e, st) {
        debugPrint('Live chat line after photo: $e\n$st');
      }
      if (!mounted) return;
      _scrollMessagesToBottom();
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tattsagramPhotoUploadFailed)),
      );
    }
  }

  /// Picks a video: camera max 8s (picker); gallery any length, trimmed to 15s + compressed.
  Future<void> _pickVideo(ImageSource source) async {
    if (!mounted) return;
    final picker = ImagePicker();

    XFile? video;
    try {
      if (source == ImageSource.camera) {
        video = await picker.pickVideo(
          source: source,
          maxDuration: const Duration(seconds: 8),
        );
      } else {
        video = await picker.pickVideo(source: source);
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? e.toString())),
      );
      return;
    }

    if (video == null || !mounted) return;

    final fromCamera = source == ImageSource.camera;
    File toUpload;
    try {
      toUpload = await TattsagramVideoPrepare.prepareForUpload(
        File(video.path),
        fromCamera: fromCamera,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not process video: $e')),
      );
      return;
    }

    await _uploadVideo(toUpload);
  }

  Future<void> _uploadVideo(File file) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Uploading video…')),
    );

    try {
      final url = await PhotoService.uploadVideo(file);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      final profile = await ProfileService.getCurrentProfile();
      final displayName = profile?.displayNameOrEmail.trim();
      final artistName =
          (displayName != null && displayName.isNotEmpty) ? displayName : 'You';

      final post = TattsagramPost(
        mediaUrl: url,
        mediaType: TattsagramMediaType.video,
        artistName: artistName,
        location: '',
        caption: '',
        timestamp: DateTime.now(),
      );
      widget.onPhotoPostedToFeed?.call(post);

      if (!mounted) return;
      try {
        await LiveMessagesService.sendLiveMessage('🎬 Video');
      } catch (e, st) {
        debugPrint('Live chat line after video: $e\n$st');
      }
      if (!mounted) return;
      _scrollMessagesToBottom();
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tattsagramPhotoUploadFailed)),
      );
    }
  }

  void _collapseToPeek() {
    FocusScope.of(context).unfocus();
    setState(() => _panelExpanded = false);
    _panelSlideController.reverse();
  }

  static const double _composerReserveHeight = 108;

  Widget _messageTextField({
    required ColorScheme scheme,
    required TextTheme textTheme,
  }) {
    return TextField(
      controller: _inputController,
      minLines: 1,
      maxLines: 4,
      style: textTheme.bodyMedium?.copyWith(
        color: Colors.black,
        fontWeight: FontWeight.w500,
      ),
      textInputAction: TextInputAction.send,
      onSubmitted: (text) {
        unawaited(_submitLiveMessage(text));
      },
      decoration: InputDecoration(
        hintText: 'Message…',
        hintStyle: const TextStyle(
          color: Color(0x99000000),
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: Colors.white.withValues(
          alpha: 0.92,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: scheme.outline.withValues(alpha: 0.45),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: scheme.primary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final w = MediaQuery.sizeOf(context).width;
    final panelW = w * 0.8;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const onChatText = Colors.black;
    final onChatMuted = Colors.black.withValues(alpha: 0.62);
    final bottomReserve =
        _composerReserveHeight + MediaQuery.paddingOf(context).bottom;

    /// Light halo so black text stays readable on dark parts of feed images.
    const legibilityShadows = <Shadow>[
      Shadow(
        color: Color(0xE6FFFFFF),
        blurRadius: 10,
        offset: Offset(0, 1),
      ),
      Shadow(
        color: Color(0xA0FFFFFF),
        blurRadius: 3,
        offset: Offset(0, 0),
      ),
    ];

    return IgnorePointer(
      ignoring: !widget.isOpen,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          if (widget.isOpen && !_panelExpanded)
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onClose,
                behavior: HitTestBehavior.opaque,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          if (widget.isOpen && _panelExpanded)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: w * 0.2,
              child: GestureDetector(
                onTap: _collapseToPeek,
                behavior: HitTestBehavior.opaque,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          AnimatedBuilder(
            animation: _panelSlideController,
            builder: (context, child) {
              final t =
                  Curves.easeInOutQuart.transform(_panelSlideController.value);
              final left = -panelW * (1.0 - t);
              return Positioned(
                left: left,
                top: 0,
                bottom: 0,
                width: panelW,
                child: child!,
              );
            },
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v < -250 && _panelExpanded) _collapseToPeek();
              },
              child: ColoredBox(
                color: Colors.transparent,
                child: SafeArea(
                  right: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Live Chat',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: onChatText,
                                  letterSpacing: -0.2,
                                  shadows: legibilityShadows,
                                ),
                              ),
                            ),
                            StreamBuilder<int>(
                              stream: _onlineUsersStream,
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                return Text(
                                  '$count online',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w700,
                                    shadows: legibilityShadows,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.black.withValues(alpha: 0.2),
                      ),
                      Expanded(
                        child: StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _liveMessagesStream,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    '${snapshot.error}',
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: onChatText,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final server = snapshot.data;
                            if (server == null) {
                              return Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.primary,
                                  ),
                                ),
                              );
                            }

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              final before = _pendingEcho.length;
                              _pendingEcho.removeWhere(
                                (p) => server.any(
                                  (s) => _echoMatchesServer(p, s),
                                ),
                              );
                              if (before != _pendingEcho.length) {
                                setState(() {});
                              }
                            });

                            final combined = <Map<String, dynamic>>[...server];
                            for (final p in _pendingEcho) {
                              if (!server.any((s) => _echoMatchesServer(p, s))) {
                                combined.add(p);
                              }
                            }
                            combined.sort(
                              (a, b) => _messageTime(a).compareTo(
                                _messageTime(b),
                              ),
                            );

                            if (combined.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'No messages yet',
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: onChatMuted,
                                      shadows: legibilityShadows,
                                    ),
                                  ),
                                ),
                              );
                            }

                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) {
                                if (mounted) _scrollMessagesToBottom();
                              },
                            );

                            return ListView.builder(
                              controller: _messageScrollController,
                              padding: EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                12 + bottomReserve,
                              ),
                              itemCount: combined.length,
                              itemBuilder: (context, i) {
                                final msg = combined[i];
                                final username =
                                    msg['username'] as String? ?? 'User';
                                final body = msg['message'] as String? ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        username,
                                        style: textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: onChatText,
                                          height: 1.2,
                                          shadows: legibilityShadows,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        body,
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: onChatText,
                                          height: 1.4,
                                          fontWeight: FontWeight.w600,
                                          shadows: legibilityShadows,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTime(
                                          context,
                                          _messageTime(msg),
                                        ),
                                        style: textTheme.bodySmall?.copyWith(
                                          color: onChatMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          shadows: legibilityShadows,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.isOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 12),
                        child: Material(
                          elevation: 4,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          color: Colors.white.withValues(alpha: 0.95),
                          child: IconButton(
                            icon: const Icon(Icons.add_a_photo),
                            tooltip: l10n.tattsagramFabShowTattoo,
                            onPressed: () => _openCamera(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: widget.showComposerBack &&
                                    widget.onComposerBack != null
                                ? 8
                                : 16,
                            bottom: 12,
                          ),
                          child: ClipRect(
                            clipBehavior: Clip.hardEdge,
                            child: SlideTransition(
                              position: _composerSlide,
                              child: _messageTextField(
                                scheme: scheme,
                                textTheme: textTheme,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.showComposerBack &&
                          widget.onComposerBack != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 16, bottom: 12),
                          child: Material(
                            elevation: 2,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.95),
                            child: IconButton(
                              tooltip: MaterialLocalizations.of(context)
                                  .backButtonTooltip,
                              icon: const Icon(Icons.arrow_back),
                              onPressed: widget.onComposerBack,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
