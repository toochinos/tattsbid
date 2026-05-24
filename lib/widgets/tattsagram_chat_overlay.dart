import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/live_message.dart';
import '../core/utils/user_type_utils.dart';
import '../core/models/tattsagram_post.dart';
import '../core/services/live_messages_service.dart';
import '../core/services/live_online_service.dart';
import '../core/services/photo_service.dart';
import '../core/services/profile_service.dart';
import '../core/services/tattsagram_post_service.dart';
import '../core/services/tattsagram_video_sound_registry.dart';
import '../l10n/app_localizations.dart';
import '../widgets/flexemo_mark.dart';
import '../widgets/safe_media_renderer.dart';
import 'user_name_with_role.dart';
import '../screens/record_page.dart';
import '../screens/video_trim_page.dart';

enum _TattsagramPickKind {
  cameraPhoto,
  galleryPhoto,
  cameraVideo,
  galleryVideo,
}

/// 11-char video id from a message body, or null. Used for oEmbed-style thumbs (no API key).
String? extractYoutubeVideoIdFromText(String text) {
  if (text.trim().isEmpty) return null;
  final t = text;
  final patterns = <RegExp>[
    RegExp(
      r'[?&]v=([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    ),
    RegExp(
      r'youtu\.be/([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    ),
    RegExp(
      r'youtube\.com/embed/([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    ),
    RegExp(
      r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    ),
    RegExp(
      r'youtube\.com/live/([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    ),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(t);
    if (m != null && (m.group(1)?.length == 11)) {
      return m.group(1);
    }
  }
  return null;
}

String _youtubeThumbnailUrl(String videoId) =>
    'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

/// Collapses ASCII + unicode spaces so message lines don’t look “stretched”.
String _normalizeChatMessageWhitespace(String raw) {
  if (raw.isEmpty) return raw;
  return raw
      .replaceAll(
        RegExp(r'[\s\u00A0\u1680\u2000-\u200B\u202F\u205F\u3000]+'),
        ' ',
      )
      .trim();
}

/// Consistent line metrics for live chat text (see STEP 5 — StrutStyle).
const StrutStyle _kLiveChatStrutName = StrutStyle(
  fontSize: 16,
  fontWeight: FontWeight.bold,
  height: 1.1,
  leading: 0,
  forceStrutHeight: true,
);
const StrutStyle _kLiveChatStrut12 = StrutStyle(
  fontSize: 12,
  height: 1.1,
  leading: 0,
  forceStrutHeight: true,
);
/// Message / caption lines (fontSize 14 on [TextStyle]); matches typical pattern:
/// `StrutStyle(height: 1.1, forceStrutHeight: true)`.
const StrutStyle _kLiveChatStrutMessageBody = StrutStyle(
  height: 1.1,
  forceStrutHeight: true,
);
const StrutStyle _kLiveChatStrut10 = StrutStyle(
  fontSize: 10,
  fontWeight: FontWeight.w600,
  height: 1.1,
  leading: 0,
  forceStrutHeight: true,
);

const double _kYoutubeChatPreviewWidth = 220;
const double _kYoutubeChatPreviewHeight = 124;

/// YouTube [hqdefault] poster behind a play affordance; falls back to black if id/url fails.
class _YoutubeChatPreviewThumb extends StatelessWidget {
  const _YoutubeChatPreviewThumb({required this.messageText});

  final String messageText;

  @override
  Widget build(BuildContext context) {
    final id = extractYoutubeVideoIdFromText(messageText);
    if (id == null) {
      return const _YoutubePreviewPlaceholder(loading: false);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: _kYoutubeChatPreviewWidth,
        height: _kYoutubeChatPreviewHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _youtubeThumbnailUrl(id),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const _YoutubePreviewPlaceholder(loading: false),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const _YoutubePreviewPlaceholder(loading: true);
              },
            ),
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 48,
                shadows: [
                  Shadow(
                    color: Color(0xB3000000),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YoutubePreviewPlaceholder extends StatelessWidget {
  const _YoutubePreviewPlaceholder({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SizedBox(
        width: _kYoutubeChatPreviewWidth,
        height: _kYoutubeChatPreviewHeight,
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                )
              : const Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 48,
                ),
        ),
      ),
    );
  }
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
    this.onCameraVideoCaptureStart,
    this.onCameraVideoCaptureCancelled,
    this.showComposerBack = false,
    this.onComposerBack,
    this.onFeedReloadAfterPost,
  });

  final bool isOpen;
  final VoidCallback onClose;
  final Duration animationDuration;

  /// Feed video mute; shared with [TattsagramPage] top-left control.
  final ValueNotifier<bool> feedSoundMuted;

  /// After a successful storage upload, adds the post to the Tattsagram scroll feed.
  final void Function(TattsagramPost post)? onPhotoPostedToFeed;
  final VoidCallback? onCameraVideoCaptureStart;
  final VoidCallback? onCameraVideoCaptureCancelled;

  /// Circular back control to the right of the message field (e.g. leave Tattsagram).
  final bool showComposerBack;
  final VoidCallback? onComposerBack;

  /// After [TattsagramPostService.createPost], re-fetch feed (e.g. [TattsagramPostService.fetchPosts]).
  final Future<void> Function()? onFeedReloadAfterPost;

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
  final TextEditingController _youtubeController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();

  /// Latest window from Realtime + REST (newest at end); trimmed to [_messageWindowLimit].
  List<LiveMessage>? _windowMessages;

  /// Older pages loaded via pull-to-refresh at the top (each batch oldest-first).
  final List<LiveMessage> _olderBatchMessages = [];

  static const int _messageWindowLimit = 100;

  StreamSubscription<List<LiveMessage>>? _messagesSub;
  Timer? _messagesPollTimer;
  bool _messagesPollRetryScheduled = false;
  bool _loadingOlder = false;
  bool _hasMoreOlder = true;
  final Set<String> _dismissedLiveChatPreviewKeys = <String>{};
  Timer? _liveChatBlinkTimer;
  bool _liveChatBlinkDim = false;

  /// When [widget.isOpen] is true: full slide panel + composer vs peek camera only.
  bool _panelExpanded = true;

  late final AnimationController _panelSlideController;
  late final Animation<Offset> _composerSlide;

  /// Shown immediately on send; removed when the same row appears from [liveChatStream].
  final List<LiveMessage> _pendingEcho = [];
  int _echoSeq = 0;
  static const int _networkRetryDelaySeconds = 2;
  static const int _maxUploadAttempts = 2;
  static const int _maxVideoDurationSeconds = 15;
  static const int _maxPreferredUploadSizeBytes = 5 * 1024 * 1024;
  int _lastUploadProgressPercent = -1;
  bool _isUploading = false;

  /// Cached `tattoo_artist` / `customer` for [LiveMessage.userId] (live chat).
  final Map<String, String?> _liveUserTypeById = {};

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  Future<void> _primeLiveChatSelfUserType() async {
    final p = await ProfileService.getCurrentProfile();
    if (!mounted || p == null) return;
    final t = canonicalUserType(p.userType);
    _safeSetState(() {
      _liveUserTypeById[p.id] = t;
    });
  }

  Future<void> _refreshLiveUserTypesForMessages(
    List<LiveMessage> messages,
  ) async {
    final ids = <String>{};
    for (final m in messages) {
      final u = m.userId?.trim();
      if (u == null || u.isEmpty) continue;
      if (_liveUserTypeById.containsKey(u)) continue;
      ids.add(u);
    }
    if (ids.isEmpty) return;
    final map = await ProfileService.getCanonicalUserTypesByUserIds(
      ids.toList(growable: false),
    );
    if (!mounted) return;
    _safeSetState(() {
      for (final id in ids) {
        _liveUserTypeById[id] = map[id];
      }
    });
  }

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
        _safeSetState(() => _liveChatBlinkDim = !_liveChatBlinkDim);
      },
    );
    unawaited(_loadInitialMessages());
    unawaited(_primeLiveChatSelfUserType());
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
    _panelSlideController.addListener(_stickMessagesToBottomDuringSlide);
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
      _scrollMessagesToBottom();
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
    _panelSlideController.removeListener(_stickMessagesToBottomDuringSlide);
    _panelSlideController.dispose();
    _messageScrollController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  bool _sameMessageRows(List<LiveMessage> a, List<LiveMessage> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  List<LiveMessage> _trimToLatestWindow(
    List<LiveMessage> ascending,
    int cap,
  ) {
    if (ascending.length <= cap) {
      return List<LiveMessage>.from(ascending);
    }
    return ascending.sublist(ascending.length - cap);
  }

  bool _wasNearLiveChatBottom() {
    if (!_messageScrollController.hasClients) return true;
    final pos = _messageScrollController.position;
    const slack = 80.0;
    return pos.maxScrollExtent - pos.pixels <= slack;
  }

  void _applyServerMessages(List<LiveMessage> rows) {
    _pendingEcho.removeWhere(
      (p) => rows.any((s) => _echoMatchesServer(p, s)),
    );
    final tail = _trimToLatestWindow(rows, _messageWindowLimit);
    if (_windowMessages != null && _sameMessageRows(_windowMessages!, tail)) {
      return;
    }
    final wasEmpty = _windowMessages == null || _windowMessages!.isEmpty;
    final nowHas = tail.isNotEmpty;
    final firstContentPaint = wasEmpty && nowHas;
    final stickToBottom = firstContentPaint || _wasNearLiveChatBottom();
    _safeSetState(() {
      _windowMessages = tail;
      if (firstContentPaint) {
        _hasMoreOlder = tail.length >= _messageWindowLimit;
      }
    });
    unawaited(_refreshLiveUserTypesForMessages(tail));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (stickToBottom) {
        if (firstContentPaint) {
          _scrollMessagesToBottomImmediately();
        } else {
          _scrollMessagesToBottom();
        }
      }
    });
  }

  Future<void> _loadInitialMessages() async {
    try {
      final rows = await LiveMessagesService.fetchMessagesForChat(
        limit: _messageWindowLimit,
      );
      if (!mounted) return;
      _applyServerMessages(rows);
    } catch (e, st) {
      debugPrint('live_messages initial load: $e\n$st');
      _safeSetState(() {
        _windowMessages = [];
        _olderBatchMessages.clear();
        _hasMoreOlder = false;
      });
    }
  }

  Future<void> _pollMessagesFromServer() async {
    try {
      final rows = await LiveMessagesService.fetchMessagesForChat(
        limit: _messageWindowLimit,
      );
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

  void _scrollMessagesToBottomImmediately() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messageScrollController.hasClients) return;
      final max = _messageScrollController.position.maxScrollExtent;
      _messageScrollController.jumpTo(max);
    });
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || !_hasMoreOlder || _windowMessages == null) {
      return;
    }
    if (_windowMessages!.isEmpty && _olderBatchMessages.isEmpty) {
      return;
    }
    final earliest = _olderBatchMessages.isNotEmpty
        ? _olderBatchMessages.first
        : _windowMessages!.first;

    double? oldPixels;
    double? oldMaxExtent;
    if (_messageScrollController.hasClients) {
      oldPixels = _messageScrollController.position.pixels;
      oldMaxExtent = _messageScrollController.position.maxScrollExtent;
    }

    _safeSetState(() => _loadingOlder = true);
    try {
      final batch = await LiveMessagesService.fetchMessagesOlderThan(
        earliest.createdAt,
        limit: 40,
      );
      if (!mounted) return;
      if (batch.isEmpty) {
        _safeSetState(() {
          _hasMoreOlder = false;
          _loadingOlder = false;
        });
        return;
      }

      final existingIds = <Object?>{
        for (final m in _olderBatchMessages) m.id,
        for (final m in _windowMessages!) m.id,
      };
      final newOnes = <LiveMessage>[
        for (final m in batch)
          if (m.id == null || !existingIds.contains(m.id)) m,
      ];

      if (newOnes.isEmpty) {
        _safeSetState(() {
          _hasMoreOlder = false;
          _loadingOlder = false;
        });
        return;
      }

      _safeSetState(() {
        _olderBatchMessages.insertAll(0, newOnes);
        _loadingOlder = false;
        if (batch.length < 40) {
          _hasMoreOlder = false;
        }
      });
      unawaited(_refreshLiveUserTypesForMessages(newOnes));

      if (oldPixels != null && oldMaxExtent != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_messageScrollController.hasClients) return;
          final newMax = _messageScrollController.position.maxScrollExtent;
          final delta = newMax - oldMaxExtent!;
          _messageScrollController.jumpTo(oldPixels! + delta);
        });
      }
    } catch (e, st) {
      debugPrint('live_messages load older: $e\n$st');
      if (mounted) {
        _safeSetState(() => _loadingOlder = false);
      }
    }
  }

  Future<void> _onRefreshLoadOlderMessages() async {
    if (!_hasMoreOlder) return;
    await _loadOlderMessages();
  }

  void _stickMessagesToBottomDuringSlide() {
    if (!mounted || !widget.isOpen || !_panelExpanded) return;
    if (!_messageScrollController.hasClients) return;
    final max = _messageScrollController.position.maxScrollExtent;
    if ((_messageScrollController.offset - max).abs() <= 0.5) return;
    _messageScrollController.jumpTo(max);
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
    final text = _youtubeController.text;
    if (text.trim().isEmpty) return;

    final username = await ProfileService.resolveLiveDisplayName();
    if (!mounted) return;

    final echoId = ++_echoSeq;
    final meId = Supabase.instance.client.auth.currentUser?.id;
    final echo = LiveMessage(
      localEchoId: echoId,
      userId: meId,
      username: username,
      message: text,
      createdAt: DateTime.now().toUtc(),
    );

    _safeSetState(() {
      _pendingEcho.add(echo);
      _youtubeController.clear();
    });
    _scrollMessagesToBottom();

    try {
      await LiveMessagesService.sendLiveMessage(text, username: username);
    } catch (e, st) {
      debugPrint('Live message send failed: $e\n$st');
      if (!mounted) return;
      _safeSetState(() {
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

    final original = File(file.path);

    try {
      debugPrint('compressing...');
      final compressed = await FlutterImageCompress.compressWithFile(
        original.path,
        minWidth: 720,
        minHeight: 1280,
        quality: 80,
      );
      if (!mounted) return;
      final uploadFile = compressed == null
          ? original
          : await File('${original.path}.feed_720.jpg')
              .writeAsBytes(compressed);
      if (!mounted) return;

      debugPrint('uploading...');
      late final String imageUrl;
      try {
        imageUrl = await PhotoService.uploadTattsagramPhoto(uploadFile);
        // ignore: avoid_print — explicit upload completion trace.
        print('UPLOAD COMPLETE');
      } catch (e, st) {
        debugPrint('Photo upload failed (keeping temp post): $e\n$st');
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        return;
      }
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      final shouldSendToFeed = await _showUploadedPhotoPopup(uploadFile.path);
      if (!mounted) return;
      if (!shouldSendToFeed) {
        return;
      }
      final artistName =
          await PhotoService.resolveArtistNameForTattsagramPost();
      if (!mounted) return;
      // ignore: avoid_print — critical upload->insert tracing.
      print('NOW INSERTING INTO DB');
      final newPost = await TattsagramPostService.createPost(
        mediaUrl: imageUrl,
        mediaType: TattsagramMediaType.image,
        artistName: artistName,
      );
      if (!mounted) return;
      widget.onPhotoPostedToFeed?.call(newPost);
      await widget.onFeedReloadAfterPost?.call();

      try {
        await LiveMessagesService.sendLiveMessage(
            l10n.tattsagramPhotoSharedInChat);
      } catch (e, st) {
        debugPrint('Live chat line after photo: $e\n$st');
      }
      if (!mounted) return;
      _scrollMessagesToBottom();
    } catch (e, st) {
      debugPrint('Photo post-create flow failed: $e\n$st');
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tattsagramPhotoUploadFailed)),
      );
    }
  }

  /// Picks video from camera (dedicated record page) or gallery.
  Future<void> _pickVideo(ImageSource source) async {
    if (!mounted) return;
    final fromCamera = source == ImageSource.camera;
    if (fromCamera) {
      widget.onCameraVideoCaptureStart?.call();
      final result = await Navigator.of(context).push<RecordPageResult>(
        MaterialPageRoute(builder: (_) => const RecordPage()),
      );
      if (!mounted) return;
      if (result == null) {
        widget.onCameraVideoCaptureCancelled?.call();
        return;
      }
      await _handleRecordedVideoUploadResult(result.videoUrl);
      widget.onCameraVideoCaptureCancelled?.call();
      return;
    }

    final picker = ImagePicker();
    XFile? video;
    try {
      video = await picker.pickVideo(source: source);
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? e.toString())),
      );
      return;
    }

    if (video == null || !mounted) return;
    final pickedFile = File(video.path);
    final tooLong = await _isVideoLongerThanLimit(
      pickedFile,
      maxSeconds: _maxVideoDurationSeconds,
    );
    if (!mounted) return;
    if (!tooLong) {
      await _uploadVideo(pickedFile);
      return;
    }

    final trimmedFile = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => VideoTrimPage(
          file: pickedFile,
          maxDurationSeconds: _maxVideoDurationSeconds,
        ),
      ),
    );
    if (!mounted || trimmedFile == null) return;
    await _uploadVideo(trimmedFile);
  }

  Future<void> _uploadVideo(File file) async {
    if (!mounted) return;
    if (_isUploading) return;
    _isUploading = true;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    _lastUploadProgressPercent = -1;
    debugPrint('[ Uploading... 0% ]');

    messenger.showSnackBar(
      const SnackBar(content: Text('Uploading video…')),
    );

    try {
      final uploadFile = await _compressVideoForUpload(file);
      print('FINAL VIDEO SIZE MB: ${uploadFile.lengthSync() / 1024 / 1024}');
      if (uploadFile.lengthSync() > 5 * 1024 * 1024) {
        throw Exception('Video too large (>5MB)');
      }
      if (!mounted) return;
      final url = await _uploadVideoWithRetry(
        uploadFile,
        onUploadProgress: (p) {
          if (!mounted) return;
          final percent = (p * 100).clamp(0, 100).round();
          if (percent != _lastUploadProgressPercent) {
            _lastUploadProgressPercent = percent;
            debugPrint('Uploading... $percent%');
          }
        },
      );
      // ignore: avoid_print — explicit upload completion trace.
      print('UPLOAD COMPLETE');
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      if (_lastUploadProgressPercent < 100) {
        _lastUploadProgressPercent = 100;
        debugPrint('Uploading... 100%');
      }

      final profile = await ProfileService.getCurrentProfile();
      if (!mounted) return;
      final displayName = profile?.displayNameOrEmail.trim();
      final artistName =
          (displayName != null && displayName.isNotEmpty) ? displayName : 'You';

      final shouldSendToFeed = await _showUploadedVideoPopup(url);
      if (!mounted) return;
      if (!shouldSendToFeed) {
        return;
      }
      // ignore: avoid_print — critical upload->insert tracing.
      print('NOW INSERTING INTO DB');
      final newPost = await TattsagramPostService.createPost(
        mediaUrl: url,
        mediaType: TattsagramMediaType.video,
        artistName: artistName,
      );
      if (!mounted) return;
      widget.onPhotoPostedToFeed?.call(newPost);
      await widget.onFeedReloadAfterPost?.call();

      if (!mounted) return;
      try {
        await LiveMessagesService.sendLiveMessage('🎬 Live video $url');
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
    } finally {
      _isUploading = false;
    }
  }

  Future<String> _uploadVideoWithRetry(
    File file, {
    void Function(double progress)? onUploadProgress,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _maxUploadAttempts; attempt++) {
      try {
        return await PhotoService.uploadVideo(
          file,
          onUploadProgress: onUploadProgress,
        );
      } catch (e) {
        lastError = e;
        if (!_isRecoverableNetworkUploadError(e) ||
            attempt == _maxUploadAttempts) {
          rethrow;
        }
        await Future<void>.delayed(
          const Duration(seconds: _networkRetryDelaySeconds),
        );
      }
    }
    throw lastError ?? Exception('Video upload failed');
  }

  bool _isRecoverableNetworkUploadError(Object e) {
    if (e is SocketException) return true;
    final t = e.toString().toLowerCase();
    return t.contains('socketexception') || t.contains('failed host lookup');
  }

  Future<File> _compressVideoForUpload(File source) async {
    final compressed = await VideoCompress.compressVideo(
      source.path,
      quality: VideoQuality.LowQuality,
      deleteOrigin: false,
    );
    var out = compressed?.file;
    if (out == null) {
      throw Exception('Video compression failed');
    }
    if (out.lengthSync() > _maxPreferredUploadSizeBytes) {
      final lower = await VideoCompress.compressVideo(
        source.path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
      );
      final lowerOut = lower?.file;
      if (lowerOut != null) {
        out = lowerOut;
      }
    }
    return out;
  }

  Future<bool> _isVideoLongerThanLimit(
    File file, {
    required int maxSeconds,
  }) async {
    try {
      final info = await VideoCompress.getMediaInfo(file.path);
      final durationMs = info.duration;
      if (durationMs == null) return false;
      return durationMs > maxSeconds * 1000;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleRecordedVideoUploadResult(String videoUrl) async {
    if (!mounted) return;
    final profile = await ProfileService.getCurrentProfile();
    if (!mounted) return;
    final displayName = profile?.displayNameOrEmail.trim();
    final artistName =
        (displayName != null && displayName.isNotEmpty) ? displayName : 'You';
    final shouldSendToFeed = await _showUploadedVideoPopup(videoUrl);
    if (!mounted) return;
    if (!shouldSendToFeed) return;
    // ignore: avoid_print — critical upload->insert tracing.
    print('NOW INSERTING INTO DB');
    final newPost = await TattsagramPostService.createPost(
      mediaUrl: videoUrl,
      mediaType: TattsagramMediaType.video,
      artistName: artistName,
    );
    if (!mounted) return;
    widget.onPhotoPostedToFeed?.call(newPost);
    await widget.onFeedReloadAfterPost?.call();

    try {
      await LiveMessagesService.sendLiveMessage('🎬 Live video $videoUrl');
    } catch (e, st) {
      debugPrint('Live chat line after video: $e\n$st');
    }
    if (!mounted) return;
    _scrollMessagesToBottom();
  }

  Future<bool> _showUploadedVideoPopup(String videoUrl) async {
    if (!mounted || videoUrl.trim().isEmpty) return false;
    final decision = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) {
        var sent = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: ColoredBox(
                          color: Colors.black,
                          child: const AspectRatio(
                            aspectRatio: 9 / 16,
                            child: SizedBox.shrink(),
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: AspectRatio(
                          aspectRatio: 9 / 16,
                          child: _UploadedVideoDialogPlayer(videoUrl: videoUrl),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(context).pop(false),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: sent
                          ? null
                          : () async {
                              setDialogState(() => sent = true);
                              await Future<void>.delayed(
                                const Duration(milliseconds: 450),
                              );
                              if (!context.mounted) return;
                              Navigator.of(context).pop(true);
                            },
                      style: ElevatedButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(16)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        sent ? 'sent!' : 'Throw it into the MIXX?',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    return decision ?? false;
  }

  Future<bool> _showUploadedPhotoPopup(String imagePath) async {
    if (!mounted || imagePath.trim().isEmpty) return false;
    final decision = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) {
        var sent = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: ColoredBox(
                          color: Colors.black,
                          child: const AspectRatio(
                            aspectRatio: 9 / 16,
                            child: SizedBox.shrink(),
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: AspectRatio(
                          aspectRatio: 9 / 16,
                          child: Image.file(
                            File(imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(color: Colors.black),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(context).pop(false),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: sent
                          ? null
                          : () async {
                              setDialogState(() => sent = true);
                              await Future<void>.delayed(
                                const Duration(milliseconds: 450),
                              );
                              if (!context.mounted) return;
                              Navigator.of(context).pop(true);
                            },
                      style: ElevatedButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(16)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        sent ? 'sent!' : 'Throw it into the MIXX?',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    return decision ?? false;
  }

  Widget _buildLiveMessagesPanel({
    required ColorScheme scheme,
    required Color onChatText,
    required Color onChatMuted,
    required List<Shadow> legibilityShadows,
    required double bottomReserve,
  }) {
    final server = _windowMessages;
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

    final combined = <LiveMessage>[..._olderBatchMessages, ...server];
    for (final p in _pendingEcho) {
      if (!combined.any((s) => _echoMatchesServer(p, s))) {
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

    return RefreshIndicator(
      color: scheme.primary,
      onRefresh: _onRefreshLoadOlderMessages,
      child: ListView.builder(
        controller: _messageScrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        padding: EdgeInsets.fromLTRB(
          4,
          2,
          4,
          2 + bottomReserve,
        ),
        itemCount: combined.length,
        itemBuilder: (context, i) {
          final msg = combined[i];
          final previewKey = _previewDismissKey(msg);
          final usernameRaw = msg.username;
          final username =
              usernameRaw.trim().isEmpty ? 'User' : usernameRaw.trim();
          final body = msg.message;
          final messageText = body;
          final messageUrl = _extractFirstUrl(body);
          final isLiveVideoPost =
              messageUrl != null && body.contains('Live video');
          final isYouTubeLink = messageText.contains('youtube.com') ||
              messageText.contains('youtu.be');
          final showYouTubePreview = isYouTubeLink &&
              !_dismissedLiveChatPreviewKeys.contains(previewKey);
          final renderedBody = isLiveVideoPost
              ? 'User just posted a new video into the MIXX!'
              : body;
          final displayBody = _normalizeChatMessageWhitespace(renderedBody);
          final nameStyle = TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            height: 1.1,
            color: _colorForLiveUsername(username),
            wordSpacing: 0,
            letterSpacing: -0.2,
            shadows: legibilityShadows,
          );
          final roleStyle = TextStyle(
            fontSize: 12,
            height: 1.1,
            color: onChatMuted,
            wordSpacing: 0,
            letterSpacing: 0,
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                UserNameWithRole(
                  name: username,
                  userType: (msg.userId != null)
                      ? _liveUserTypeById[msg.userId!]
                      : null,
                  nameStyle: nameStyle,
                  roleStyle: roleStyle,
                  nameStrutStyle: _kLiveChatStrutName,
                  roleStrutStyle: _kLiveChatStrut12,
                ),
                const SizedBox(height: 2),
                if (showYouTubePreview)
                  GestureDetector(
                    onTap: () async {
                      final url = Uri.parse(messageText);
                      await launchUrl(url);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            _YoutubeChatPreviewThumb(messageText: messageText),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Material(
                                color: Colors.black54,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () {
                                    _safeSetState(() {
                                      _dismissedLiveChatPreviewKeys
                                          .add(previewKey);
                                    });
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to watch on YouTube',
                          textAlign: TextAlign.start,
                          strutStyle: _kLiveChatStrutMessageBody,
                          style: const TextStyle(
                            fontSize: 14,
                            wordSpacing: 0,
                            letterSpacing: 0,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: messageUrl == null
                        ? null
                        : () => unawaited(
                              isLiveVideoPost
                                  ? _openLiveVideoUrl(messageUrl)
                                  : _openMessageUrl(messageUrl),
                            ),
                    child: AnimatedOpacity(
                      opacity: isLiveVideoPost
                          ? (_liveChatBlinkDim ? 0.35 : 1.0)
                          : 1.0,
                      duration: const Duration(milliseconds: 420),
                      child: Text(
                        displayBody,
                        textAlign: TextAlign.start,
                        textDirection: TextDirection.ltr,
                        strutStyle: _kLiveChatStrutMessageBody,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          wordSpacing: 0,
                          letterSpacing: 0,
                          color: isLiveVideoPost
                              ? Colors.white
                              : (messageUrl == null
                                  ? Colors.white
                                  : Colors.blue),
                          height: 1.1,
                          fontFamilyFallback: _emojiFontFamilyFallback,
                          decoration: messageUrl == null || isLiveVideoPost
                              ? TextDecoration.none
                              : TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(context, msg.createdAt),
                  strutStyle: _kLiveChatStrut10,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.1,
                    color: onChatMuted,
                    fontWeight: FontWeight.w600,
                    shadows: legibilityShadows,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _collapseToPeek() {
    FocusScope.of(context).unfocus();
    _safeSetState(() => _panelExpanded = false);
    _panelSlideController.reverse();
  }

  static const double _composerReserveHeight = 108;

  String? _extractFirstUrl(String input) {
    final m = RegExp(r'(https?:\/\/\S+)').firstMatch(input);
    if (m == null) return null;
    final url = m.group(1)?.trim();
    if (url == null || url.isEmpty) return null;
    return url;
  }

  String _previewDismissKey(LiveMessage msg) {
    final id = msg.id?.toString().trim();
    if (id != null && id.isNotEmpty) return id;
    return '${msg.createdAt.toIso8601String()}|${msg.username}|${msg.message}';
  }

  Future<void> _openMessageUrl(String rawUrl) async {
    final url = Uri.tryParse(rawUrl);
    if (url == null) return;
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openLiveVideoUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: _UploadedVideoDialogPlayer(videoUrl: uri.toString()),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _messageTextField({
    required ColorScheme scheme,
  }) {
    return TextField(
      controller: _youtubeController,
      minLines: 1,
      maxLines: 4,
      keyboardType: TextInputType.text,
      textAlign: TextAlign.start,
      textDirection: TextDirection.ltr,
      style: const TextStyle(
        fontSize: 15,
        color: Colors.white,
        fontWeight: FontWeight.w500,
        wordSpacing: 0,
        letterSpacing: 0,
        fontFamilyFallback: _emojiFontFamilyFallback,
      ),
      textInputAction: TextInputAction.send,
      onSubmitted: (_) {
        unawaited(_submitLiveMessage());
      },
      decoration: InputDecoration(
        hintText: 'Paste YouTube link',
        hintStyle: const TextStyle(
          color: Color(0x99FFFFFF),
          fontWeight: FontWeight.w400,
          wordSpacing: 0,
          letterSpacing: 0,
          fontFamilyFallback: _emojiFontFamilyFallback,
        ),
        isDense: true,
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
          horizontal: 12,
          vertical: 10,
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
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                        child: Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.hardEdge,
                          children: [
                            _buildLiveMessagesPanel(
                              scheme: scheme,
                              onChatText: onChatText,
                              onChatMuted: onChatMuted,
                              legibilityShadows: legibilityShadows,
                              bottomReserve: bottomReserve,
                            ),
                            Positioned(
                              top: 22,
                              right: 6,
                              child: IgnorePointer(
                                child: FlexemoMark(
                                  size: 180,
                                  errorFallback: Icon(
                                    Icons.photo_library_outlined,
                                    size: 140,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                                  icon: const Icon(Icons.home),
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

class _UploadedVideoDialogPlayer extends StatefulWidget {
  const _UploadedVideoDialogPlayer({required this.videoUrl});

  final String videoUrl;

  @override
  State<_UploadedVideoDialogPlayer> createState() =>
      _UploadedVideoDialogPlayerState();
}

class _UploadedVideoDialogPlayerState
    extends State<_UploadedVideoDialogPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(1.0);
      await c.play();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _ready = false);
    }
  }

  @override
  void dispose() {
    final c = _controller;
    _controller = null;
    if (c != null) {
      c.pause();
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (!_ready || c == null || !c.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
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
}
