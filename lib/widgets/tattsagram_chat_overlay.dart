import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/models/live_message.dart';
import '../core/models/tattsagram_post.dart';
import '../core/services/live_messages_service.dart';
import '../core/services/profile_service.dart';
import '../core/services/live_online_service.dart';
import '../core/services/photo_service.dart';
import '../core/services/tattsagram_video_prepare.dart';
import '../core/services/tattsagram_video_sound_registry.dart';
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
    required this.feedSoundMuted,
    this.animationDuration = const Duration(milliseconds: 820),
    this.onPhotoPostedToFeed,
    required this.onInsertTempVideoAtTop,
    required this.onReplaceTempVideoWhenFinished,
    this.onPendingVideoUploadFailed,
    this.showComposerBack = false,
    this.onComposerBack,
  });

  final bool isOpen;
  final VoidCallback onClose;
  final Duration animationDuration;

  /// Feed video mute; shared with [TattsagramPage] top-left control.
  final ValueNotifier<bool> feedSoundMuted;

  /// After a successful storage upload, adds the post to the Tattsagram scroll feed.
  final void Function(TattsagramPost post)? onPhotoPostedToFeed;

  /// Step 2 — feed should `_chatPosts.insert(0, TattsagramPost.tempVideoUpload(...))`.
  final void Function(String tempPostId, String localVideoPath)
      onInsertTempVideoAtTop;

  /// Step 4 — same slot as the temp row: `isUploading: false`, `uploadProgress: 1.0`, URLs set.
  final void Function(String tempPostId, String videoUrl, String artistName)
      onReplaceTempVideoWhenFinished;

  /// Removes the optimistic row when background video upload fails ([tempPost.id]).
  final void Function(String localTempPostId)? onPendingVideoUploadFailed;

  /// Circular back control to the right of the message field (e.g. leave Tattsagram).
  final bool showComposerBack;
  final VoidCallback? onComposerBack;

  @override
  State<TattsagramChatOverlay> createState() => _TattsagramChatOverlayState();
}

class _TattsagramChatOverlayState extends State<TattsagramChatOverlay>
    with SingleTickerProviderStateMixin {
  static const bool _cameraUploadEnabled = true;

  /// After primary platform font so emoji resolve (Apple / Windows / Android).
  static const List<String> _emojiFontFamilyFallback = [
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Noto Color Emoji',
  ];

  late final Stream<int> _onlineUsersStream;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();

  /// Server rows (Realtime + periodic REST refresh so other users appear without hot restart).
  List<LiveMessage>? _serverMessages;
  StreamSubscription<List<LiveMessage>>? _messagesSub;
  Timer? _messagesPollTimer;
  bool _messagesPollRetryScheduled = false;
  Timer? _liveChatBlinkTimer;
  bool _liveChatBlinkDim = false;

  /// When [widget.isOpen] is true: full slide panel + composer vs peek camera only.
  bool _panelExpanded = true;

  late final AnimationController _panelSlideController;
  late final Animation<Offset> _composerSlide;

  /// Shown immediately on send; removed when the same row appears from [liveChatStream].
  final List<LiveMessage> _pendingEcho = [];
  int _echoSeq = 0;

  @override
  void initState() {
    super.initState();
    _onlineUsersStream = LiveOnlineService.onlineUsers();
    _messagesSub = LiveMessagesService.liveChatStream().listen(
      (rows) {
        if (!mounted) return;
        _applyServerMessages(List<LiveMessage>.from(rows));
      },
      onError: (Object e, StackTrace st) {
        debugPrint('live_messages stream error: $e\n$st');
      },
    );
    _messagesPollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(_pollMessagesFromServer()),
    );
    _liveChatBlinkTimer = Timer.periodic(
      const Duration(milliseconds: 900),
      (_) {
        if (!mounted) return;
        setState(() => _liveChatBlinkDim = !_liveChatBlinkDim);
      },
    );
    unawaited(_loadInitialMessages());
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
    _messagesPollTimer?.cancel();
    _liveChatBlinkTimer?.cancel();
    final sub = _messagesSub;
    _messagesSub = null;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    _panelSlideController.dispose();
    _messageScrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  bool _sameMessageRows(List<LiveMessage> a, List<LiveMessage> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _applyServerMessages(List<LiveMessage> rows) {
    _pendingEcho.removeWhere(
      (p) => rows.any((s) => _echoMatchesServer(p, s)),
    );
    if (_serverMessages != null && _sameMessageRows(_serverMessages!, rows)) {
      return;
    }
    setState(() => _serverMessages = rows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollMessagesToBottom();
    });
  }

  Future<void> _loadInitialMessages() async {
    try {
      final rows = await LiveMessagesService.fetchMessagesForChat();
      if (!mounted) return;
      _applyServerMessages(rows);
    } catch (e, st) {
      debugPrint('live_messages initial load: $e\n$st');
      if (mounted) {
        setState(() {
          _serverMessages = [];
        });
      }
    }
  }

  Future<void> _pollMessagesFromServer() async {
    try {
      final rows = await LiveMessagesService.fetchMessagesForChat();
      if (!mounted) return;
      _applyServerMessages(rows);
      _messagesPollRetryScheduled = false;
    } catch (e) {
      final asText = e.toString().toLowerCase();
      final isNetworkLookupFailure =
          e is SocketException || asText.contains('failed host lookup');
      if (!isNetworkLookupFailure) {
        return;
      }
      if (_messagesPollRetryScheduled) return;
      _messagesPollRetryScheduled = true;
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      _messagesPollRetryScheduled = false;
      unawaited(_pollMessagesFromServer());
    }
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

  bool _echoMatchesServer(LiveMessage echo, LiveMessage serverRow) {
    return echo.username == serverRow.username &&
        echo.message == serverRow.message;
  }

  /// Saturated dark hues — readable on light areas of the feed; [legibilityShadows] still help on dark media.
  static const List<Color> _usernamePalette = [
    Color(0xFF0D47A1),
    Color(0xFF4A148C),
    Color(0xFFB71C1C),
    Color(0xFF1B5E20),
    Color(0xFFE65100),
    Color(0xFF006064),
    Color(0xFF4E342E),
    Color(0xFF880E4F),
    Color(0xFF1A237E),
    Color(0xFF004D40),
    Color(0xFFF57F17),
    Color(0xFF33691E),
    Color(0xFF4527A0),
    Color(0xFFBF360C),
    Color(0xFF827717),
    Color(0xFF00695C),
  ];

  static Color _colorForLiveUsername(String username) {
    final key = username.toLowerCase().trim();
    if (key.isEmpty) return const Color(0xFF212121);
    final i = key.hashCode.abs() % _usernamePalette.length;
    return _usernamePalette[i];
  }

  Future<void> _submitLiveMessage() async {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;

    final username = await ProfileService.resolveLiveDisplayName();
    if (!mounted) return;

    final echoId = ++_echoSeq;
    final echo = LiveMessage(
      localEchoId: echoId,
      username: username,
      message: text,
      createdAt: DateTime.now().toUtc(),
    );

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
        _pendingEcho.removeWhere((p) => p.localEchoId == echoId);
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
    if (!_cameraUploadEnabled) return;
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
      final original = File(file.path);
      final compressed = await FlutterImageCompress.compressWithFile(
        original.path,
        minWidth: 720,
        minHeight: 1280,
        quality: 80,
      );
      final uploadFile = compressed == null
          ? original
          : await File('${original.path}.feed_720.jpg')
              .writeAsBytes(compressed);

      final url = await PhotoService.uploadTattsagramPhoto(uploadFile);
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onPhotoPostedToFeed?.call(post);
      });

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

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempBase =
        TattsagramPost.tempVideoUpload(id: tempId, localVideo: file.path);
    widget.onInsertTempVideoAtTop(tempId, file.path);

    messenger.showSnackBar(
      const SnackBar(content: Text('Uploading video…')),
    );

    try {
      final url = await PhotoService.uploadVideo(
        file,
        onUploadProgress: (p) {
          if (!mounted) return;
          widget.onPhotoPostedToFeed?.call(
            tempBase.copyWith(uploadProgress: p),
          );
        },
      );
      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      final profile = await ProfileService.getCurrentProfile();
      final displayName = profile?.displayNameOrEmail.trim();
      final artistName =
          (displayName != null && displayName.isNotEmpty) ? displayName : 'You';

      widget.onReplaceTempVideoWhenFinished(tempId, url, artistName);

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
      widget.onPendingVideoUploadFailed?.call(tempId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tattsagramPhotoUploadFailed)),
      );
    }
  }

  Widget _buildLiveMessagesPanel({
    required ColorScheme scheme,
    required Color onChatText,
    required Color onChatMuted,
    required List<Shadow> legibilityShadows,
    required double bottomReserve,
  }) {
    final server = _serverMessages;
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

    final combined = <LiveMessage>[...server];
    for (final p in _pendingEcho) {
      if (!server.any((s) => _echoMatchesServer(p, s))) {
        combined.add(p);
      }
    }
    combined.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (combined.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No messages yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: onChatMuted,
              shadows: legibilityShadows,
            ),
          ),
        ),
      );
    }

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
        final usernameRaw = msg.username;
        final username =
            usernameRaw.trim().isEmpty ? 'User' : usernameRaw.trim();
        final body = msg.message;
        final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: _colorForLiveUsername(username),
              letterSpacing: -0.2,
              shadows: legibilityShadows,
            );
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: titleStyle,
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  fontFamilyFallback: _emojiFontFamilyFallback,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(context, msg.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onChatMuted,
                  shadows: legibilityShadows,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _collapseToPeek() {
    FocusScope.of(context).unfocus();
    setState(() => _panelExpanded = false);
    _panelSlideController.reverse();
  }

  static const double _composerReserveHeight = 108;

  Widget _messageTextField({
    required ColorScheme scheme,
  }) {
    return TextField(
      controller: _inputController,
      minLines: 1,
      maxLines: 4,
      keyboardType: TextInputType.text,
      style: const TextStyle(
        fontSize: 15,
        color: Colors.white,
        fontWeight: FontWeight.w500,
        fontFamilyFallback: _emojiFontFamilyFallback,
      ),
      textInputAction: TextInputAction.send,
      onSubmitted: (_) {
        unawaited(_submitLiveMessage());
      },
      decoration: InputDecoration(
        hintText: 'Message…',
        hintStyle: const TextStyle(
          color: Color(0x99FFFFFF),
          fontWeight: FontWeight.w400,
          fontFamilyFallback: _emojiFontFamilyFallback,
        ),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.45),
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
                      Transform.translate(
                        offset: const Offset(0, -10),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 12, 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Expanded(
                                child: AnimatedOpacity(
                                  opacity: _liveChatBlinkDim ? 0.45 : 1.0,
                                  duration: const Duration(milliseconds: 420),
                                  curve: Curves.easeInOut,
                                  child: Text(
                                    'Live Chat',
                                    style: textTheme.titleMedium?.copyWith(
                                      fontSize:
                                          (textTheme.titleMedium?.fontSize ??
                                                  16) +
                                              3,
                                      fontWeight: FontWeight.w800,
                                      color: onChatText,
                                      letterSpacing: -0.2,
                                      shadows: legibilityShadows,
                                    ),
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
                                      height: 1.0,
                                      shadows: legibilityShadows,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.black.withValues(alpha: 0.2),
                      ),
                      Expanded(
                        child: _buildLiveMessagesPanel(
                          scheme: scheme,
                          onChatText: onChatText,
                          onChatMuted: onChatMuted,
                          legibilityShadows: legibilityShadows,
                          bottomReserve: bottomReserve,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.isOpen && !_panelExpanded)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _liveChatBlinkDim ? 0.2 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    child: const Text(
                      'PRESS + SLIDE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: Color(0xB3000000),
                            blurRadius: 10,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
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
                      if (_cameraUploadEnabled) ...[
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
                      ],
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            right: 8,
                            bottom: 12,
                          ),
                          child: ClipRect(
                            clipBehavior: Clip.hardEdge,
                            child: SlideTransition(
                              position: _composerSlide,
                              child: _messageTextField(
                                scheme: scheme,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 16, bottom: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ValueListenableBuilder<bool>(
                              valueListenable: widget.feedSoundMuted,
                              builder: (context, muted, _) {
                                return Material(
                                  elevation: 2,
                                  shape: const CircleBorder(),
                                  clipBehavior: Clip.antiAlias,
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.95),
                                  child: IconButton(
                                    tooltip: muted ? 'Unmute' : 'Mute',
                                    icon: Icon(
                                      muted
                                          ? Icons.volume_off
                                          : Icons.volume_up,
                                    ),
                                    onPressed: () {
                                      final v = !widget.feedSoundMuted.value;
                                      widget.feedSoundMuted.value = v;
                                      TattsagramVideoSoundRegistry
                                          .setUserSoundMuted(v);
                                    },
                                  ),
                                );
                              },
                            ),
                            if (widget.showComposerBack &&
                                widget.onComposerBack != null) ...[
                              const SizedBox(height: 8),
                              Material(
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
                            ],
                          ],
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
