import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/tattsagram_post.dart';
import '../core/services/live_online_service.dart';
import '../core/services/tattsagram_feed_media_pool.dart';
import '../core/services/tattsagram_like_service.dart';
import '../core/services/tattsagram_post_service.dart';
import '../core/services/tattsagram_ranked_pool_feed.dart';
import '../core/services/tattsagram_video_sound_registry.dart';
import '../widgets/tattsagram_chat_overlay.dart';
import '../widgets/tattsagram_pooled_video.dart';

Future<void> sharePost(String imageUrl) async {
  final url = imageUrl.trim();
  if (url.isEmpty) return;
  final response = await http.get(Uri.parse(url));
  if (response.statusCode < 200 || response.statusCode >= 300) return;

  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/share.jpg');
  await file.writeAsBytes(response.bodyBytes);

  await Share.shareXFiles(
    [XFile(file.path)],
    text: "You know this guy… look what he's flexing now 👀🔥",
  );
}

Future<void> shareVideo(String videoUrl) async {
  try {
    // 1. Download video
    final response = await http.get(Uri.parse(videoUrl));

    if (response.statusCode != 200) {
      throw Exception('Failed to download video');
    }

    // 2. Save to temp storage
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/share_video.mp4');

    await file.writeAsBytes(response.bodyBytes);

    // 3. Share video
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Check this out on Flexemo 🔥',
    );
  } catch (e) {
    print('SHARE ERROR: $e');
  }
}

Future<void> shareToApp(String mediaUrl, {required bool isVideo}) =>
    isVideo ? shareVideo(mediaUrl) : sharePost(mediaUrl);

void showShareOptions(
  BuildContext context,
  String mediaUrl, {
  required bool isVideo,
}) {
  showModalBottomSheet(
    context: context,
    builder: (_) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Messenger'),
            onTap: () {
              Navigator.of(context).pop();
              unawaited(shareToApp(mediaUrl, isVideo: isVideo));
            },
          ),
          ListTile(
            title: const Text('Instagram'),
            onTap: () {
              Navigator.of(context).pop();
              unawaited(shareToApp(mediaUrl, isVideo: isVideo));
            },
          ),
          ListTile(
            title: const Text('TikTok'),
            onTap: () {
              Navigator.of(context).pop();
              unawaited(shareToApp(mediaUrl, isVideo: isVideo));
            },
          ),
          ListTile(
            title: const Text('Facebook'),
            onTap: () {
              Navigator.of(context).pop();
              unawaited(shareToApp(mediaUrl, isVideo: isVideo));
            },
          ),
          ListTile(
            title: const Text('Email'),
            onTap: () {
              Navigator.of(context).pop();
              unawaited(shareToApp(mediaUrl, isVideo: isVideo));
            },
          ),
        ],
      );
    },
  );
}

/// Social-style vertical feed of tattoo posts (minimal UI).
class TattsagramPage extends StatefulWidget {
  const TattsagramPage({
    super.key,
    this.onLeaveFullScreen,
    this.feedPlaybackListenable,
  });

  /// When set (e.g. from [MainShellPage] full-screen mode), shown as AppBar back control.
  final VoidCallback? onLeaveFullScreen;

  /// When false (other tab selected), feed videos pause and mute. Null = always on.
  final ValueListenable<bool>? feedPlaybackListenable;

  @override
  State<TattsagramPage> createState() => _TattsagramPageState();
}

class _TattsagramPageState extends State<TattsagramPage> {
  // 1-2-3 stack: previous / active / next visible together.
  // Show a full stacked set (top/middle/bottom) more clearly on landing.
  static const double _pageViewportFraction = 0.3334;

  /// Open on entry so users immediately see Live Chat, composer, and camera affordances.
  bool _chatOpen = true;

  /// Unique posts (pool). Ranked expansion uses [TattsagramRankedPoolFeed.score].
  late List<TattsagramPost> _uniquePool;

  /// Shuffled expanded sequence: `score` copies per post, shuffled once per rebuild.
  late List<TattsagramPost> _feedSequence;

  /// After a like: weights change but sequence is not rebuilt until [near-end] load.
  bool _needsSequenceRebuild = false;

  late final ScrollController _feedScrollController;
  late PageController _feedPageController;
  late final ValueNotifier<bool> _feedPlaybackGate;

  /// Full-screen vertical feed (TikTok-style); entered by tapping a video on the landing feed.
  bool _isTikTokFullscreen = false;
  bool _snapPlaybackEnabled = true;
  bool _isSnapping = false;
  int? _gestureStartAbsIndex;
  int? _snappedAbsIndex;
  int _currentIndex = 0;

  static const int _nearEndSlots = 10;
  static const double _snapThresholdPx = 8;

  /// Latest rows from Supabase `tattsagram_post`.
  List<TattsagramPost> _remotePosts = [];

  /// Live-chat uploads until the same [TattsagramPost.canonicalRemoteUrl] exists in [_remotePosts].
  final List<TattsagramPost> _chatPosts = [];

  /// False until the first remote fetch attempt finishes (success or error).
  bool _remoteLoadDone = false;
  static const int _remotePageSize = 40;
  static const int _nearSequenceEndThreshold = 5;
  int _remoteFetchOffset = 0;
  bool _loadingMoreRemotePosts = false;
  bool _hasMoreRemotePosts = true;

  /// Dedupes concurrent like/unlike calls per post (id or canonical URL for chat-only).
  final Set<String> _likePersistInFlight = {};

  /// Refreshes [live_online.last_seen] while this screen is visible.
  Timer? _onlineHeartbeat;
  Timer? _realtimeRetryTimer;

  RealtimeChannel? _tattsagramPostsChannel;
  StreamSubscription<AuthState>? _authStateSub;

  /// Shared with [TattsagramChatOverlay] so feed + live chat mute controls stay in sync.
  late final ValueNotifier<bool> _feedSoundMuted;

  /// Pooled decoders + image precache for the vertical feed (current ± window).
  final TattsagramFeedMediaPool _feedMediaPool = TattsagramFeedMediaPool();
  bool _feedMediaPoolSyncScheduled = false;

  static const int _loopItemMultiplier = 400;
  bool _refreshingAuthSession = false;
  String? _tempOverlayImagePath;
  bool _tempOverlayVisible = false;
  bool _tempOverlayAtTop = false;
  Timer? _tempOverlayHideTimer;
  bool _cameraCaptureGateActive = false;
  Timer? _cameraCaptureReleaseTimer;

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final phase = WidgetsBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(fn);
      });
      return;
    }
    setState(fn);
  }

  void _attachFeedPageListener() {
    _feedPageController.addListener(_onFeedPageScroll);
  }

  void _detachFeedPageListener() {
    _feedPageController.removeListener(_onFeedPageScroll);
  }

  /// Active = page nearest center (updates while user scrolls, not only on settle).
  void _onFeedPageScroll() {
    if (!_feedPageController.hasClients) return;
    final page = _feedPageController.page;
    if (page == null) return;
    final L = _feedSequence.length;
    if (L == 0) return;
    // Warm media on every scroll tick (fractional page) so N+1…N+3 buffer *before* settle.
    if (_remoteLoadDone) {
      _warmMediaPoolNow(scrollPage: page);
    }
    final next = page.round().clamp(0, L - 1);
    _maybeLoadMoreRemotePostsNearEnd(next, L);
    if (next == _currentIndex) {
      _scheduleWarmMediaPool();
      return;
    }
    _safeSetState(() {
      _currentIndex = next;
    });
    _scheduleWarmMediaPool();
  }

  List<TattsagramPost> _sequenceForMediaPool() {
    return _removeNearDuplicatesForVisibleWindow(_feedSequence);
  }

  void _scheduleWarmMediaPool() {
    if (_feedMediaPoolSyncScheduled) return;
    _feedMediaPoolSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _feedMediaPoolSyncScheduled = false;
      if (!mounted) return;
      _warmMediaPoolNow();
    });
  }

  void _warmMediaPoolNow({double? scrollPage}) {
    if (!_remoteLoadDone || !mounted) return;
    final seq = _sequenceForMediaPool();
    if (seq.isEmpty) return;
    final c = _currentIndex.clamp(0, seq.length - 1);
    var pageArg = scrollPage;
    if (pageArg == null && _feedPageController.hasClients) {
      pageArg = _feedPageController.page;
    }
    _feedMediaPool.syncWarmRing(
      sequence: seq,
      committedCenter: c,
      context: context,
      scrollPage: pageArg,
    );
  }

  void _maybeLoadMoreRemotePostsNearEnd(int index, int sequenceLength) {
    if (!_remoteLoadDone || !_hasMoreRemotePosts || _loadingMoreRemotePosts) {
      return;
    }
    if (sequenceLength <= 0) return;
    if (index < sequenceLength - _nearSequenceEndThreshold) return;
    unawaited(_loadMoreRemoteTattsagramPosts());
  }

  @override
  void initState() {
    super.initState();
    _feedSoundMuted =
        ValueNotifier(TattsagramVideoSoundRegistry.userSoundMuted);
    unawaited(LiveOnlineService.setOnline());
    _onlineHeartbeat = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(LiveOnlineService.setOnline()),
    );
    _uniquePool = [];
    _feedSequence = [];
    _recomposeFeedAndWeights();
    _feedPlaybackGate = ValueNotifier<bool>(true);
    widget.feedPlaybackListenable?.addListener(_recomputeFeedPlaybackGate);
    _recomputeFeedPlaybackGate();
    _feedScrollController = ScrollController();
    _feedScrollController.addListener(_onFeedScrollCombined);
    _feedPageController =
        PageController(viewportFraction: _pageViewportFraction);
    _attachFeedPageListener();
    _connectPostsRealtime();
    _authStateSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        _tattsagramPostsChannel?.unsubscribe();
        _tattsagramPostsChannel = null;
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        _reconnectPostsRealtime();
      }
    });
    unawaited(_recoverAuthSessionOnStart());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadRemoteTattsagramPosts());
    });
  }

  void _connectPostsRealtime() {
    _realtimeRetryTimer?.cancel();
    try {
      _tattsagramPostsChannel = Supabase.instance.client
          .channel('posts')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'tattsagram_post',
            callback: _onRealtimePostInserted,
          )
          .subscribe((status, [Object? error]) {
        final statusText = status.toString().toLowerCase();
        final failed = statusText.contains('channelerror') ||
            statusText.contains('timedout') ||
            _isRecoverableRealtimeError(error);
        if (!failed) return;
        _scheduleRealtimeReconnect();
      });
    } catch (e) {
      if (_isRecoverableRealtimeError(e)) {
        _scheduleRealtimeReconnect();
        return;
      }
    }
  }

  void _reconnectPostsRealtime() {
    _tattsagramPostsChannel?.unsubscribe();
    _connectPostsRealtime();
  }

  void _scheduleRealtimeReconnect() {
    _realtimeRetryTimer?.cancel();
    _realtimeRetryTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _reconnectPostsRealtime();
    });
  }

  Future<void> _silentlyRefreshSession() async {
    if (_refreshingAuthSession) return;
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession != null) return;
    _refreshingAuthSession = true;
    try {
      await auth.refreshSession();
    } catch (_) {
      // Keep existing session state; do not force sign out on transient failures.
    } finally {
      _refreshingAuthSession = false;
    }
  }

  bool _isRecoverableRealtimeError(Object? error) {
    if (error == null) return false;
    if (error is RealtimeSubscribeException || error is SocketException) {
      return true;
    }
    final t = error.toString().toLowerCase();
    return t.contains('failed host lookup') ||
        t.contains('socketexception') ||
        t.contains('network');
  }

  Future<void> _recoverAuthSessionOnStart() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) return;
    await _silentlyRefreshSession();
  }

  void _onRealtimePostInserted(PostgresChangePayload payload) {
    if (!mounted) return;
    final row = Map<String, dynamic>.from(payload.newRecord);
    final postDebug = <String, dynamic>{
      'video_url': row['video_url'] ?? row['media_url'],
    };
    print("FEED VIDEO URL: ${postDebug['video_url']}");
    final post = TattsagramPostService.postFromRealtimeRow(row);

    if (post.id != null && post.id!.isNotEmpty) {
      if (_remotePosts.any((p) => p.id == post.id)) return;
      if (_chatPosts.any((p) => p.id == post.id)) return;
    }
    final remoteKey = post.canonicalRemoteUrl;
    if (remoteKey.isNotEmpty) {
      if (_remotePosts.any((p) => p.canonicalRemoteUrl == remoteKey)) {
        return;
      }
      if (_chatPosts.any((p) => p.canonicalRemoteUrl == remoteKey)) {
        return;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _remotePosts.insert(0, post);
        _remoteFetchOffset++;
        _mergeUniquePoolFromSources();
      });
      _rebuildRankedSequencePreservingAnchor();
      _scheduleWarmMediaPool();
    });
  }

  @override
  void didUpdateWidget(covariant TattsagramPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feedPlaybackListenable != widget.feedPlaybackListenable) {
      oldWidget.feedPlaybackListenable
          ?.removeListener(_recomputeFeedPlaybackGate);
      widget.feedPlaybackListenable?.addListener(_recomputeFeedPlaybackGate);
      _recomputeFeedPlaybackGate();
    }
  }

  void _mergeUniquePoolFromSources() {
    final remoteUrls = _remotePosts.map((p) => p.canonicalRemoteUrl).toSet();
    final chat = _chatPosts
        .where((p) => !remoteUrls.contains(p.canonicalRemoteUrl))
        .toList(growable: false);
    _uniquePool = [...chat, ..._remotePosts];
  }

  /// Rebuilds [_uniquePool] from chat + remote and reshuffles the ranked expanded sequence.
  void _recomposeFeedAndWeights() {
    _mergeUniquePoolFromSources();
    _feedSequence =
        TattsagramRankedPoolFeed.buildShuffledRankedSequence(_uniquePool);
  }

  Future<void> _loadRemoteTattsagramPosts() async {
    try {
      final posts = await TattsagramPostService.fetchPosts(limit: 100);
      final withLikes = List<TattsagramPost>.from(posts, growable: true);
      debugPrint('Fetched posts: ${posts.length}');
      _safeSetState(() {
        _remotePosts = List<TattsagramPost>.from(withLikes);
        _remoteFetchOffset = withLikes.length;
        _hasMoreRemotePosts = posts.length == 100;
        _remoteLoadDone = true;
        _recomposeFeedAndWeights();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _seedLoopScrollOffset();
        _scheduleWarmMediaPool();
      });
    } catch (e, st) {
      debugPrint('Tattsagram remote load failed: $e\n$st');
      _safeSetState(() {
        _remoteLoadDone = true;
      });
    }
  }

  Future<void> _loadMoreRemoteTattsagramPosts() async {
    if (_loadingMoreRemotePosts || !_hasMoreRemotePosts) return;
    _loadingMoreRemotePosts = true;
    try {
      final posts = await TattsagramPostService.fetchPosts(
        limit: _remotePageSize,
        offset: _remoteFetchOffset,
      );
      _remoteFetchOffset += posts.length;
      if (posts.length < _remotePageSize) {
        _hasMoreRemotePosts = false;
      }
      if (posts.isEmpty || !mounted) {
        return;
      }

      final existingIds = _remotePosts
          .map((p) => p.id)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      final existingUrls =
          _remotePosts.map((p) => p.canonicalRemoteUrl).toSet();
      final dedupedNew = posts.where((p) {
        final id = p.id?.trim() ?? '';
        if (id.isNotEmpty && existingIds.contains(id)) {
          return false;
        }
        final url = p.canonicalRemoteUrl.trim();
        if (url.isNotEmpty && existingUrls.contains(url)) {
          return false;
        }
        return true;
      }).toList(growable: false);

      if (dedupedNew.isEmpty) return;

      _safeSetState(() {
        _remotePosts.addAll(dedupedNew);
        _mergeUniquePoolFromSources();
      });
      _rebuildRankedSequencePreservingAnchor();
      _scheduleWarmMediaPool();
    } catch (e, st) {
      debugPrint('Tattsagram remote pagination failed: $e\n$st');
    } finally {
      _loadingMoreRemotePosts = false;
    }
  }

  @override
  void dispose() {
    _realtimeRetryTimer?.cancel();
    _cameraCaptureReleaseTimer?.cancel();
    _tempOverlayHideTimer?.cancel();
    _authStateSub?.cancel();
    _tattsagramPostsChannel?.unsubscribe();
    widget.feedPlaybackListenable?.removeListener(_recomputeFeedPlaybackGate);
    _feedPlaybackGate.dispose();
    _feedSoundMuted.dispose();
    _onlineHeartbeat?.cancel();
    _feedScrollController
      ..removeListener(_onFeedScrollCombined)
      ..dispose();
    _detachFeedPageListener();
    _feedPageController.dispose();
    unawaited(_feedMediaPool.disposeAll());
    super.dispose();
  }

  void _showOptimisticPhotoOverlay(String path) {
    _tempOverlayHideTimer?.cancel();
    _safeSetState(() {
      _tempOverlayImagePath = path;
      _tempOverlayVisible = true;
      _tempOverlayAtTop = false;
    });
    _tempOverlayHideTimer = Timer(const Duration(milliseconds: 5000), () {
      if (!mounted) return;
      setState(() {
        _tempOverlayAtTop = true;
      });
    });
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 5220)).then((_) {
        if (!mounted) return;
        setState(() {
          _tempOverlayVisible = false;
        });
      }),
    );
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 5440)).then((_) {
        if (!mounted) return;
        if (!_tempOverlayVisible) {
          setState(() {
            _tempOverlayImagePath = null;
            _tempOverlayAtTop = false;
          });
        }
      }),
    );
  }

  void _enterTikTokMode(int index) {
    final L = _feedSequence.length;
    if (L == 0) return;
    final i = index.clamp(0, L - 1);
    _detachFeedPageListener();
    _feedPageController.dispose();
    _feedPageController = PageController(
      initialPage: i,
      viewportFraction: 1.0,
    );
    _attachFeedPageListener();
    _safeSetState(() {
      _currentIndex = i;
      _isTikTokFullscreen = true;
    });
    _scheduleWarmMediaPool();
  }

  void _exitTikTokMode() {
    if (!_isTikTokFullscreen) return;
    final L = _feedSequence.length;
    if (L == 0) {
      _safeSetState(() => _isTikTokFullscreen = false);
      return;
    }
    final i = _currentIndex.clamp(0, L - 1);
    _detachFeedPageListener();
    _feedPageController.dispose();
    _feedPageController = PageController(
      initialPage: i,
      viewportFraction: _pageViewportFraction,
    );
    _attachFeedPageListener();
    _safeSetState(() {
      _currentIndex = i;
      _isTikTokFullscreen = false;
    });
    _scheduleWarmMediaPool();
  }

  void _onVideoCellTapped(int index) {
    if (_isTikTokFullscreen) {
      unawaited(
        _feedPageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        ),
      );
    } else {
      _enterTikTokMode(index);
    }
  }

  int get _sequenceLength => _feedSequence.length;

  void _onFeedScrollCombined() {
    _repositionInfiniteScroll();
    _maybeRebuildRankedSequenceNearEnd();
  }

  double _itemExtentForWidth(double width) => width;

  void _seedLoopScrollOffset() {
    final c = _feedScrollController;
    if (!mounted || !c.hasClients) return;
    final w = MediaQuery.sizeOf(context).width;
    final n = _sequenceLength;
    if (w <= 0 || n == 0) return;
    final cycle = n * w;
    c.jumpTo(cycle * 100);
    final viewport = c.position.viewportDimension;
    final centerPx = c.offset + viewport / 2;
    final maxIndex = (_sequenceLength * _loopItemMultiplier) - 1;
    _snappedAbsIndex = ((centerPx - w / 2) / w).round().clamp(0, maxIndex);
  }

  void _repositionInfiniteScroll() {
    final c = _feedScrollController;
    if (!mounted || !c.hasClients) return;
    final w = MediaQuery.sizeOf(context).width;
    final n = _sequenceLength;
    if (w <= 0 || n == 0) return;
    final cycle = n * w;
    final o = c.offset;
    if (o < cycle * 8) {
      c.jumpTo(o + cycle * 120);
    } else if (o > cycle * (_loopItemMultiplier - 12)) {
      c.jumpTo(o - cycle * 120);
    }
  }

  /// Rebuild expanded pool from current [likesCount], shuffle; keep the same post on screen.
  void _rebuildRankedSequencePreservingAnchor() {
    final c = _feedScrollController;
    if (!mounted) return;
    final oldL = _feedSequence.length;
    final w = _itemExtentForWidth(MediaQuery.sizeOf(context).width);
    final absIndex =
        c.hasClients && w > 0 && oldL > 0 ? (c.offset / w).floor() : 0;
    final oldIdx = oldL > 0 ? ((absIndex % oldL) + oldL) % oldL : 0;
    final anchor = oldL > 0 ? _feedSequence[oldIdx] : null;
    final lap = oldL > 0 ? absIndex ~/ oldL : 0;

    _feedSequence =
        TattsagramRankedPoolFeed.buildShuffledRankedSequence(_uniquePool);
    _needsSequenceRebuild = false;

    final newL = _feedSequence.length;
    _safeSetState(() {});
    _scheduleWarmMediaPool();

    if (!c.hasClients || w <= 0 || newL == 0 || anchor == null) {
      return;
    }

    var newIdx = 0;
    for (var i = 0; i < newL; i++) {
      if (TattsagramRankedPoolFeed.samePost(_feedSequence[i], anchor)) {
        newIdx = i;
        break;
      }
    }
    final newAbs = lap * newL + newIdx;
    final target = newAbs * w;
    _snappedAbsIndex = newAbs;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !c.hasClients) return;
      final clamped = target.clamp(0.0, c.position.maxScrollExtent);
      if ((c.offset - clamped).abs() > 0.5) {
        c.jumpTo(clamped);
      }
      _scheduleWarmMediaPool();
    });
  }

  void _maybeRebuildRankedSequenceNearEnd() {
    if (!_needsSequenceRebuild) return;
    if (!_feedScrollController.hasClients || !mounted) return;
    final w = _itemExtentForWidth(MediaQuery.sizeOf(context).width);
    final L = _sequenceLength;
    if (w <= 0 || L == 0) return;
    final absIndex = (_feedScrollController.offset / w).floor();
    final idx = ((absIndex % L) + L) % L;
    if (idx < L - _nearEndSlots) return;
    _rebuildRankedSequencePreservingAnchor();
  }

  void _replaceInUniquePool(TattsagramPost updated) {
    for (var i = 0; i < _uniquePool.length; i++) {
      if (TattsagramRankedPoolFeed.samePost(_uniquePool[i], updated)) {
        _uniquePool[i] = updated;
        return;
      }
    }
  }

  String _likeDedupeKey(TattsagramPost post) =>
      (post.id != null && post.id!.isNotEmpty)
          ? post.id!
          : post.canonicalRemoteUrl;

  void _applyOptimisticLike(TattsagramPost post, {required bool wasLiked}) {
    final delta = wasLiked ? -1 : 1;
    final nextCount = (post.likesCount + delta).clamp(0, 1 << 30);
    final updated = post.copyWith(
      likesCount: nextCount,
      isLikedByMe: !wasLiked,
    );
    _replaceInUniquePool(updated);
    TattsagramRankedPoolFeed.syncPostInstances(_feedSequence, updated);
    _needsSequenceRebuild = true;
    _safeSetState(() {});
  }

  void _revertLikeTo(TattsagramPost snapshot) {
    _replaceInUniquePool(snapshot);
    TattsagramRankedPoolFeed.syncPostInstances(_feedSequence, snapshot);
    _needsSequenceRebuild = true;
    _safeSetState(() {});
  }

  /// Optimistic UI; persists to `tattsagram_likes` (triggers maintain `likes_count`).
  void _onToggleLike(TattsagramPost post) {
    final key = _likeDedupeKey(post);
    if (_likePersistInFlight.contains(key)) return;

    final wasLiked = post.isLikedByMe;
    final serverId = post.id;
    final hasServerRow = serverId != null && serverId.isNotEmpty;

    if (!hasServerRow) {
      final remoteUrl = post.canonicalRemoteUrl;
      _likePersistInFlight.add(key);
      final snapshot = post;
      _applyOptimisticLike(post, wasLiked: wasLiked);
      if (remoteUrl.isNotEmpty) {
        unawaited(_persistLikeByResolvedMediaUrl(
          snapshot: snapshot,
          remoteUrl: remoteUrl,
          wasLiked: wasLiked,
          dedupeKey: key,
        ));
      } else {
        _likePersistInFlight.remove(key);
      }
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to like posts')),
      );
      return;
    }

    _likePersistInFlight.add(key);
    final snapshot = post;
    _applyOptimisticLike(post, wasLiked: wasLiked);

    unawaited(_persistLikeToServer(
      snapshot: snapshot,
      serverId: serverId,
      wasLiked: wasLiked,
      dedupeKey: key,
    ));
  }

  Future<void> _persistLikeByResolvedMediaUrl({
    required TattsagramPost snapshot,
    required String remoteUrl,
    required bool wasLiked,
    required String dedupeKey,
  }) async {
    try {
      final resolvedId =
          await TattsagramLikeService.resolvePostIdByMediaUrl(remoteUrl);
      if (resolvedId == null || resolvedId.isEmpty) {
        if (mounted) _revertLikeTo(snapshot);
        return;
      }
      if (wasLiked) {
        await TattsagramLikeService.removeLike(postId: resolvedId);
      } else {
        await TattsagramLikeService.addLike(postId: resolvedId);
      }
    } on PostgrestException catch (e) {
      if (!wasLiked && (e.code == '23505')) {
        final aligned = snapshot.copyWith(isLikedByMe: true);
        _replaceInUniquePool(aligned);
        TattsagramRankedPoolFeed.syncPostInstances(_feedSequence, aligned);
        _needsSequenceRebuild = true;
        if (mounted) setState(() {});
      } else {
        if (mounted) _revertLikeTo(snapshot);
      }
    } catch (_) {
      if (mounted) _revertLikeTo(snapshot);
    } finally {
      _likePersistInFlight.remove(dedupeKey);
    }
  }

  Future<void> _persistLikeToServer({
    required TattsagramPost snapshot,
    required String serverId,
    required bool wasLiked,
    required String dedupeKey,
  }) async {
    try {
      if (wasLiked) {
        await TattsagramLikeService.removeLike(postId: serverId);
      } else {
        await TattsagramLikeService.addLike(postId: serverId);
      }
    } on PostgrestException catch (e) {
      if (!wasLiked && (e.code == '23505')) {
        final aligned = snapshot.copyWith(isLikedByMe: true);
        _replaceInUniquePool(aligned);
        TattsagramRankedPoolFeed.syncPostInstances(_feedSequence, aligned);
        _needsSequenceRebuild = true;
        if (mounted) setState(() {});
      } else {
        debugPrint('Tattsagram like persist failed: $e');
        if (mounted) _revertLikeTo(snapshot);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update like: ${e.message}')),
          );
        }
      }
    } catch (e, st) {
      debugPrint('Tattsagram like persist failed: $e\n$st');
      if (mounted) {
        _revertLikeTo(snapshot);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update like: $e')),
        );
      }
    } finally {
      _likePersistInFlight.remove(dedupeKey);
    }
  }

  void _recomputeFeedPlaybackGate() {
    final externalAllows = widget.feedPlaybackListenable?.value ?? true;
    final next =
        externalAllows && _snapPlaybackEnabled && !_cameraCaptureGateActive;
    if (_feedPlaybackGate.value != next) {
      _feedPlaybackGate.value = next;
    }
  }

  void _pauseFeedForCameraCapture() {
    _cameraCaptureReleaseTimer?.cancel();
    _cameraCaptureGateActive = true;
    _recomputeFeedPlaybackGate();
  }

  void _pauseAllFeedVideos() {
    print('VIDEO_RECORDING_STARTED — pausing all media');
    _pauseFeedForCameraCapture();
  }

  void _cancelCameraCapturePause() {
    _cameraCaptureReleaseTimer?.cancel();
    _cameraCaptureGateActive = false;
    _recomputeFeedPlaybackGate();
  }

  int _middleInsertIndex(int listLength) {
    if (listLength <= 0) return 0;
    return _currentIndex.clamp(0, listLength);
  }

  void _setSnapPlaybackEnabled(bool enabled) {
    if (_snapPlaybackEnabled == enabled) return;
    _snapPlaybackEnabled = enabled;
    _recomputeFeedPlaybackGate();
  }

  void _resumePlaybackAfterSnap() {
    _setSnapPlaybackEnabled(true);
    // Run after layout settles so the snapped tile is measured in the yellow zone.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
    });
  }

  // ignore: unused_element
  Future<void> _snapNearestToCenterOnScrollEnd() async {
    final c = _feedScrollController;
    if (!mounted || !c.hasClients || _isSnapping) return;
    final extent = _itemExtentForWidth(MediaQuery.sizeOf(context).width);
    if (extent <= 0) {
      _setSnapPlaybackEnabled(true);
      return;
    }

    final viewport = c.position.viewportDimension;
    final centerPx = c.offset + viewport / 2;
    final maxIndex = (_sequenceLength * _loopItemMultiplier) - 1;
    if (maxIndex <= 0) {
      _resumePlaybackAfterSnap();
      _gestureStartAbsIndex = null;
      return;
    }
    final nearestIndex =
        ((centerPx - extent / 2) / extent).round().clamp(0, maxIndex);
    final startIndex = _gestureStartAbsIndex;
    final stepLockedIndex = startIndex == null
        ? nearestIndex
        : nearestIndex.clamp(startIndex - 1, startIndex + 1);
    final targetOffset = (stepLockedIndex * extent - (viewport - extent) / 2)
        .clamp(0.0, c.position.maxScrollExtent);
    final delta = (c.offset - targetOffset).abs();

    if (delta <= _snapThresholdPx) {
      if (_snappedAbsIndex != stepLockedIndex) {
        setState(() {
          _snappedAbsIndex = stepLockedIndex;
        });
      }
      _resumePlaybackAfterSnap();
      _gestureStartAbsIndex = null;
      return;
    }

    _isSnapping = true;
    _setSnapPlaybackEnabled(false);
    try {
      await c.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutQuart,
      );
      // Hard-lock exact alignment so the tile does not drift off the snap zone.
      if (c.hasClients) {
        c.jumpTo(targetOffset);
      }
      if (mounted && _snappedAbsIndex != stepLockedIndex) {
        setState(() {
          _snappedAbsIndex = stepLockedIndex;
        });
      }
    } finally {
      _isSnapping = false;
      if (mounted) {
        _resumePlaybackAfterSnap();
        _gestureStartAbsIndex = null;
      }
    }
  }

  /// Step 2 — temp video row at top before upload completes.
  void _onInsertTempVideoAtTop(String tempPostId, String localVideoPath) {
    setState(() {
      _chatPosts.insert(
        0,
        TattsagramPost.tempVideoUpload(
          id: tempPostId,
          localVideo: localVideoPath,
        ),
      );
      _mergeUniquePoolFromSources();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rebuildRankedSequencePreservingAnchor();
    });
  }

  /// Step 4 — replace the temp tile (same [tempPostId]): `isUploading: false`,
  /// `uploadProgress: 1.0`, remote URLs; clear other optimistic uploads.
  void _onReplaceTempVideoWhenFinished(
    String tempPostId,
    String videoUrl,
    String artistName,
  ) {
    setState(() {
      final completedVideoPost = TattsagramPost(
        mediaUrl: videoUrl,
        mediaType: TattsagramMediaType.video,
        artistName: artistName,
        location: '',
        caption: '',
        timestamp: DateTime.now(),
        isUploading: false,
        uploadProgress: 1.0,
        videoUrl: videoUrl,
      );
      final i = _chatPosts.indexWhere((p) => p.id == tempPostId);
      if (i >= 0) {
        _chatPosts[i] = _chatPosts[i].copyWith(
          isUploading: false,
          uploadProgress: 1.0,
          mediaUrl: videoUrl,
          videoUrl: videoUrl,
          localVideo: null,
          artistName: artistName,
          timestamp: DateTime.now(),
        );
      } else {
        _chatPosts.insert(
          0,
          completedVideoPost,
        );
      }
      _remotePosts = List<TattsagramPost>.from(_remotePosts);
      _remotePosts.removeWhere(
        (p) => p.canonicalRemoteUrl == completedVideoPost.canonicalRemoteUrl,
      );
      _remotePosts.insert(
        0,
        completedVideoPost,
      );
      _chatPosts.removeWhere((p) => p.isUploading);
      _mergeUniquePoolFromSources();
    });
    _cancelCameraCapturePause();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rebuildRankedSequencePreservingAnchor();
    });
  }

  void _onPhotoPostedFromLiveChat(TattsagramPost post) {
    if (!mounted) return;
    String? overlayPathToShow;
    setState(() {
      if (post.mediaType == TattsagramMediaType.image) {
        if (post.isUploading && (post.id?.isNotEmpty ?? false)) {
          if (_chatOpen) {
            _chatOpen = false;
          }
          final localPath = post.mediaUrl.trim();
          if (localPath.isNotEmpty) {
            final uri = Uri.tryParse(localPath);
            final isRemote =
                uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
            if (!isRemote) {
              overlayPathToShow = (uri != null && uri.scheme == 'file')
                  ? uri.toFilePath()
                  : localPath;
            }
          }
          final pid = post.id!;
          // Insert optimistic image directly into page-level feed sources immediately.
          _remotePosts = List<TattsagramPost>.from(_remotePosts);
          final remoteI = _remotePosts.indexWhere((p) => p.id == pid);
          if (remoteI >= 0) {
            _remotePosts[remoteI] = post;
          } else {
            _remotePosts.insert(0, post);
          }
          final i = _chatPosts.indexWhere((p) => p.id == pid);
          if (i >= 0) {
            _chatPosts[i] = post;
          } else {
            _chatPosts.insert(0, post);
          }
        } else {
          final replaceId = post.replacesLocalUploadId;
          if (replaceId != null && replaceId.isNotEmpty) {
            _remotePosts = List<TattsagramPost>.from(_remotePosts);
            final tempRemoteI =
                _remotePosts.indexWhere((p) => p.id == replaceId);
            _chatPosts.removeWhere((p) => p.id == replaceId);
            if (tempRemoteI >= 0) {
              _remotePosts[tempRemoteI] = post;
            } else {
              _remotePosts.removeWhere(
                (p) => p.canonicalRemoteUrl == post.canonicalRemoteUrl,
              );
              _remotePosts.insert(0, post);
            }
          } else {
            _remotePosts = List<TattsagramPost>.from(_remotePosts);
            _remotePosts.removeWhere(
              (p) => p.canonicalRemoteUrl == post.canonicalRemoteUrl,
            );
            _remotePosts.insert(0, post);
          }
          _chatPosts.removeWhere(
            (p) => p.canonicalRemoteUrl == post.canonicalRemoteUrl,
          );
        }
      } else {
        _chatPosts.removeWhere(
          (p) => p.canonicalRemoteUrl == post.canonicalRemoteUrl,
        );
        final pid = post.id;
        _remotePosts = List<TattsagramPost>.from(_remotePosts);
        _remotePosts.removeWhere(
          (p) => p.canonicalRemoteUrl == post.canonicalRemoteUrl,
        );
        _remotePosts.insert(0, post);
        if (pid != null && pid.isNotEmpty) {
          final i = _chatPosts.indexWhere((p) => p.id == pid);
          if (i >= 0) {
            _chatPosts[i] = post;
          } else {
            _chatPosts.insert(0, post);
          }
        } else {
          _chatPosts.insert(0, post);
        }
      }
      _mergeUniquePoolFromSources();
    });
    if (overlayPathToShow != null && overlayPathToShow!.isNotEmpty) {
      _showOptimisticPhotoOverlay(overlayPathToShow!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rebuildRankedSequencePreservingAnchor();
    });
  }

  void _onPendingVideoUploadFailed(String localTempPostId) {
    setState(() {
      _chatPosts.removeWhere((p) => p.id == localTempPostId);
      _remotePosts = List<TattsagramPost>.from(_remotePosts);
      _remotePosts.removeWhere((p) => p.id == localTempPostId);
      _mergeUniquePoolFromSources();
    });
    _cancelCameraCapturePause();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rebuildRankedSequencePreservingAnchor();
    });
  }

  bool _isSamePostForVisibleWindow(TattsagramPost a, TattsagramPost b) {
    final aId = a.id?.trim() ?? '';
    final bId = b.id?.trim() ?? '';
    if (aId.isNotEmpty && bId.isNotEmpty) {
      return aId == bId;
    }
    final aUrl = a.canonicalRemoteUrl.trim();
    final bUrl = b.canonicalRemoteUrl.trim();
    return aUrl.isNotEmpty && bUrl.isNotEmpty && aUrl == bUrl;
  }

  List<TattsagramPost> _removeNearDuplicatesForVisibleWindow(
    List<TattsagramPost> source,
  ) {
    if (source.length < 2) return source;
    final seq = List<TattsagramPost>.from(source);
    for (var i = 0; i < seq.length; i++) {
      final dupPrev = i > 0 && _isSamePostForVisibleWindow(seq[i], seq[i - 1]);
      final dupPrev2 = i > 1 && _isSamePostForVisibleWindow(seq[i], seq[i - 2]);
      if (!dupPrev && !dupPrev2) continue;

      var swapIndex = -1;
      for (var j = i + 1; j < seq.length; j++) {
        final conflictsPrev =
            i > 0 && _isSamePostForVisibleWindow(seq[j], seq[i - 1]);
        final conflictsPrev2 =
            i > 1 && _isSamePostForVisibleWindow(seq[j], seq[i - 2]);
        if (!conflictsPrev && !conflictsPrev2) {
          swapIndex = j;
          break;
        }
      }
      if (swapIndex != -1) {
        final tmp = seq[i];
        seq[i] = seq[swapIndex];
        seq[swapIndex] = tmp;
      }
    }
    return seq;
  }

  Widget _buildFeed() {
    if (!_remoteLoadDone) {
      return const Center(child: CircularProgressIndicator());
    }
    final seq = _removeNearDuplicatesForVisibleWindow(_feedSequence);
    final L = seq.length;
    if (L == 0) {
      return const Center(
        child: Text('No Flexemo posts yet'),
      );
    }
    if (_currentIndex >= L) _currentIndex = L - 1;

    if (_isTikTokFullscreen) {
      return PageView.builder(
        controller: _feedPageController,
        scrollDirection: Axis.vertical,
        padEnds: false,
        allowImplicitScrolling: false,
        pageSnapping: true,
        itemCount: L,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          final p = seq[index];
          final isActive = index == _currentIndex;
          final mountDecoder =
              isActive && p.mediaType == TattsagramMediaType.video;
          return _TattsagramFeedItem(
            key: ValueKey(TattsagramFeedMediaPool.slotKey(index, p)),
            feedIndex: index,
            mediaPool: _feedMediaPool,
            post: p,
            isCenter: isActive,
            mountVideoDecoder: mountDecoder,
            onVideoSurfaceTap: null,
            onVideoThumbnailTap:
                isActive && p.mediaType == TattsagramMediaType.video
                    ? () => _onVideoCellTapped(index)
                    : null,
            centerPlaybackListenable: _feedPlaybackGate,
            soundMutedListenable: _feedSoundMuted,
            onLike: () => _onToggleLike(p),
          );
        },
      );
    }

    return PageView.builder(
      controller: _feedPageController,
      scrollDirection: Axis.vertical,
      padEnds: true,
      allowImplicitScrolling: true,
      itemCount: L,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      itemBuilder: (context, index) {
        final p = seq[index];
        return _TattsagramFeedItem(
          key: ValueKey(TattsagramFeedMediaPool.slotKey(index, p)),
          feedIndex: index,
          mediaPool: _feedMediaPool,
          post: p,
          isCenter: index == _currentIndex,
          mountVideoDecoder: p.mediaType == TattsagramMediaType.video,
          onVideoSurfaceTap:
              index == _currentIndex && p.mediaType == TattsagramMediaType.video
                  ? () => _enterTikTokMode(index)
                  : null,
          onVideoThumbnailTap: null,
          centerPlaybackListenable: _feedPlaybackGate,
          soundMutedListenable: _feedSoundMuted,
          onLike: () => _onToggleLike(p),
        );
      },
    );
  }

  void _handleBack() {
    if (widget.onLeaveFullScreen != null) {
      widget.onLeaveFullScreen!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  bool get _showBackFab =>
      widget.onLeaveFullScreen != null || Navigator.of(context).canPop();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final backTooltip = MaterialLocalizations.of(context).backButtonTooltip;

    return PopScope(
      canPop: !_isTikTokFullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isTikTokFullscreen) {
          _exitTikTokMode();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: MediaQuery.removeViewInsets(
                removeBottom: true,
                context: context,
                child: _buildFeed(),
              ),
            ),
            if (_tempOverlayImagePath != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedAlign(
                    alignment: _tempOverlayAtTop
                        ? Alignment.topCenter
                        : Alignment.center,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: _tempOverlayAtTop
                            ? MediaQuery.paddingOf(context).top + 10
                            : 0,
                      ),
                      child: AnimatedOpacity(
                        opacity: _tempOverlayVisible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: AnimatedScale(
                          scale: _tempOverlayVisible ? 1.0 : 0.92,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: MediaQuery.sizeOf(context).width * 0.78,
                              child: AspectRatio(
                                aspectRatio: 9 / 16,
                                child: Image.file(
                                  File(_tempOverlayImagePath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: MediaQuery.sizeOf(context).width * 0.78,
                  height: MediaQuery.sizeOf(context).width * 0.78,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.transparent, width: 2),
                  ),
                ),
              ),
            ),
            if (_isTikTokFullscreen)
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  minimum: const EdgeInsets.only(top: 8, left: 8),
                  child: Material(
                    elevation: 2,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.95),
                    child: IconButton(
                      tooltip: 'Close fullscreen',
                      icon: const Icon(Icons.fullscreen_exit),
                      onPressed: _exitTikTokMode,
                    ),
                  ),
                ),
              ),
            if (_isTikTokFullscreen)
              Positioned(
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  left: false,
                  minimum: const EdgeInsets.only(right: 16, bottom: 12),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _feedSoundMuted,
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
                            muted ? Icons.volume_off : Icons.volume_up,
                          ),
                          onPressed: () {
                            final v = !_feedSoundMuted.value;
                            _feedSoundMuted.value = v;
                            TattsagramVideoSoundRegistry.setUserSoundMuted(v);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (!_isTikTokFullscreen && !_chatOpen)
              Positioned(
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  left: false,
                  minimum: const EdgeInsets.only(right: 16, bottom: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_showBackFab) ...[
                        Material(
                          elevation: 2,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          color: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.95),
                          child: IconButton(
                            tooltip: backTooltip,
                            icon: const Icon(Icons.arrow_back),
                            onPressed: _handleBack,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Material(
                        elevation: 2,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.95),
                        child: IconButton(
                          tooltip: 'Live chat',
                          icon: const Icon(Icons.chat_bubble_outline),
                          onPressed: () => setState(() => _chatOpen = true),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<bool>(
                        valueListenable: _feedSoundMuted,
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
                                muted ? Icons.volume_off : Icons.volume_up,
                              ),
                              onPressed: () {
                                final v = !_feedSoundMuted.value;
                                _feedSoundMuted.value = v;
                                TattsagramVideoSoundRegistry.setUserSoundMuted(
                                  v,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            if (!_isTikTokFullscreen)
              TattsagramChatOverlay(
                isOpen: _chatOpen,
                onClose: () => setState(() => _chatOpen = false),
                onPhotoPostedToFeed: _onPhotoPostedFromLiveChat,
                onInsertTempVideoAtTop: _onInsertTempVideoAtTop,
                onReplaceTempVideoWhenFinished: _onReplaceTempVideoWhenFinished,
                onPendingVideoUploadFailed: _onPendingVideoUploadFailed,
                onPendingPhotoUploadFailed: _onPendingVideoUploadFailed,
                onCameraVideoCaptureStart: _pauseAllFeedVideos,
                onCameraVideoCaptureCancelled: _cancelCameraCapturePause,
                feedSoundMuted: _feedSoundMuted,
                showComposerBack: _showBackFab,
                onComposerBack: _handleBack,
              ),
          ],
        ),
      ),
    );
  }
}

class _TattsagramVideoThumbnailOnly extends StatelessWidget {
  const _TattsagramVideoThumbnailOnly({
    required this.post,
    required this.scheme,
  });

  final TattsagramPost post;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final thumb = post.thumbnailUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumb,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (_, __) => ColoredBox(
          color: scheme.surfaceContainerHighest,
        ),
        errorWidget: (_, __, ___) => _fallback,
      );
    }
    return _fallback;
  }

  Widget get _fallback => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.videocam_outlined,
            size: 56,
            color: scheme.outline,
          ),
        ),
      );
}

class _TattsagramFeedItem extends StatelessWidget {
  const _TattsagramFeedItem({
    super.key,
    required this.feedIndex,
    required this.mediaPool,
    required this.post,
    required this.isCenter,
    required this.mountVideoDecoder,
    this.onVideoSurfaceTap,
    this.onVideoThumbnailTap,
    required this.centerPlaybackListenable,
    required this.soundMutedListenable,
    required this.onLike,
  });

  final int feedIndex;
  final TattsagramFeedMediaPool mediaPool;
  final TattsagramPost post;
  final bool isCenter;
  final bool mountVideoDecoder;
  final VoidCallback? onVideoSurfaceTap;
  final VoidCallback? onVideoThumbnailTap;
  final ValueListenable<bool> centerPlaybackListenable;
  final ValueListenable<bool> soundMutedListenable;
  final VoidCallback onLike;

  Widget _media(ColorScheme scheme) {
    if (post.mediaType == TattsagramMediaType.video) {
      if (mountVideoDecoder) {
        return TattsagramPooledVideo(
          feedIndex: feedIndex,
          post: post,
          pool: mediaPool,
          thumbnailUrl: post.thumbnailUrl,
          feedPlaybackListenable: isCenter
              ? centerPlaybackListenable
              : const AlwaysStoppedAnimation<bool>(false),
          soundMutedListenable: soundMutedListenable,
          onSurfaceTap: onVideoSurfaceTap,
        );
      }
      return _TattsagramVideoThumbnailOnly(post: post, scheme: scheme);
    }
    final imagePath = post.mediaUrl.trim();
    final uri = Uri.tryParse(imagePath);
    final isRemote =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final localPath =
        (uri != null && uri.scheme == 'file') ? uri.toFilePath() : imagePath;
    if (!isRemote && localPath.isNotEmpty) {
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: scheme.outline,
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: post.mediaUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => ColoredBox(
        color: scheme.surfaceContainerHighest,
      ),
      errorWidget: (_, __, ___) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(
          Icons.broken_image_outlined,
          size: 48,
          color: scheme.outline,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final media = _media(scheme);
    final mediaWithGestures = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onVideoThumbnailTap,
      onDoubleTap: isCenter ? onLike : null,
      child: media,
    );
    const actionStyle = TextStyle(
      color: Colors.white,
      fontSize: 13,
      shadows: [
        Shadow(
          color: Color(0x80000000),
          blurRadius: 8,
          offset: Offset(0, 1),
        ),
      ],
    );
    const iconShadows = [
      Shadow(
        color: Color(0x80000000),
        blurRadius: 8,
        offset: Offset(0, 1),
      ),
    ];

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          mediaWithGestures,
          if (post.isUploading)
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black54,
                child: Text(
                  'Uploading ${(post.uploadProgress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: onLike,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            post.isLikedByMe
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.white,
                            size: 28,
                            shadows: iconShadows,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${post['likes_count'] ?? 0}',
                            textAlign: TextAlign.center,
                            style: actionStyle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => unawaited(
                        shareVideo((post.videoUrl ?? post.mediaUrl).trim()),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.share_outlined,
                            color: Colors.white,
                            size: 28,
                            shadows: iconShadows,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Share',
                            textAlign: TextAlign.center,
                            style: actionStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 28, 14, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      post.artistName,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        height: 1.2,
                        shadows: const [
                          Shadow(
                            color: Color(0x80000000),
                            blurRadius: 12,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
