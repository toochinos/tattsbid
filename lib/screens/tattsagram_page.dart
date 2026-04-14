import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/tattsagram_post.dart';
import '../core/services/live_online_service.dart';
import '../core/services/tattsagram_like_service.dart';
import '../core/services/tattsagram_post_service.dart';
import '../core/services/tattsagram_ranked_pool_feed.dart';
import '../core/services/tattsagram_video_sound_registry.dart';
import '../widgets/tattsagram_chat_overlay.dart';
import '../widgets/video_player_widget.dart';

const String _tattsagramPostBaseUrl = 'https://tattsagram.com/post';

void sharePost(Map post) {
  final id = post['id'];
  if (id == null) return;
  final s = id.toString().trim();
  if (s.isEmpty) return;
  unawaited(
    Share.share('$_tattsagramPostBaseUrl/$s'),
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
  static const double _pageViewportFraction = 0.36;

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

  /// Dedupes concurrent like/unlike calls per post (id or canonical URL for chat-only).
  final Set<String> _likePersistInFlight = {};

  /// Refreshes [live_online.last_seen] while this screen is visible.
  Timer? _onlineHeartbeat;

  RealtimeChannel? _tattsagramPostsChannel;

  /// Shared with [TattsagramChatOverlay] so feed + live chat mute controls stay in sync.
  late final ValueNotifier<bool> _feedSoundMuted;

  static const int _loopItemMultiplier = 400;

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
    _tattsagramPostsChannel = Supabase.instance.client
        .channel('posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tattsagram_post',
          callback: (payload) {
            if (!mounted) return;
            final row = Map<String, dynamic>.from(payload.newRecord);
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

            setState(() {
              _remotePosts.insert(0, post);
              _mergeUniquePoolFromSources();
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _rebuildRankedSequencePreservingAnchor();
            });
          },
        )
        .subscribe();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadRemoteTattsagramPosts());
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
      final ids = posts
          .map((p) => p.id)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();
      final likedIds = await TattsagramLikeService.fetchLikedPostIds(ids);
      final withLikes = posts.map((p) {
        final id = p.id;
        if (id == null || id.isEmpty) return p;
        return p.copyWith(isLikedByMe: likedIds.contains(id));
      }).toList(growable: false);
      debugPrint('Fetched posts: ${withLikes.length}');
      if (!mounted) return;
      setState(() {
        _remotePosts = withLikes;
        _remoteLoadDone = true;
        _recomposeFeedAndWeights();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _seedLoopScrollOffset();
        TattsagramVideoSoundRegistry.beginScrollSoundPass();
        TattsagramVideoSoundRegistry.scheduleFinalizeSoundPass();
      });
    } catch (e, st) {
      debugPrint('Tattsagram remote load failed: $e\n$st');
      if (mounted) {
        setState(() {
          _remoteLoadDone = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _tattsagramPostsChannel?.unsubscribe();
    widget.feedPlaybackListenable?.removeListener(_recomputeFeedPlaybackGate);
    _feedPlaybackGate.dispose();
    _feedSoundMuted.dispose();
    _onlineHeartbeat?.cancel();
    _feedScrollController
      ..removeListener(_onFeedScrollCombined)
      ..dispose();
    _feedPageController.dispose();
    super.dispose();
  }

  void _enterTikTokMode(int index) {
    final L = _feedSequence.length;
    if (L == 0) return;
    final i = index.clamp(0, L - 1);
    _feedPageController.dispose();
    _feedPageController = PageController(
      initialPage: i,
      viewportFraction: 1.0,
    );
    setState(() {
      _currentIndex = i;
      _isTikTokFullscreen = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onFeedScrollSoundPass();
      TattsagramVideoSoundRegistry.scheduleFinalizeSoundPass();
    });
  }

  void _exitTikTokMode() {
    if (!_isTikTokFullscreen) return;
    final L = _feedSequence.length;
    if (L == 0) {
      setState(() => _isTikTokFullscreen = false);
      return;
    }
    final i = _currentIndex.clamp(0, L - 1);
    _feedPageController.dispose();
    _feedPageController = PageController(
      initialPage: i,
      viewportFraction: _pageViewportFraction,
    );
    setState(() {
      _currentIndex = i;
      _isTikTokFullscreen = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onFeedScrollSoundPass();
      TattsagramVideoSoundRegistry.scheduleFinalizeSoundPass();
    });
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
    _onFeedScrollSoundPass();
    _repositionInfiniteScroll();
    _maybeRebuildRankedSequenceNearEnd();
  }

  double _itemExtentForWidth(double width) => width;

  void _onFeedScrollSoundPass() {
    if (!_feedPlaybackGate.value) return;
    TattsagramVideoSoundRegistry.beginScrollSoundPass();
    TattsagramVideoSoundRegistry.scheduleFinalizeSoundPass();
  }

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
    setState(() {});

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
    setState(() {});
  }

  void _revertLikeTo(TattsagramPost snapshot) {
    _replaceInUniquePool(snapshot);
    TattsagramRankedPoolFeed.syncPostInstances(_feedSequence, snapshot);
    _needsSequenceRebuild = true;
    setState(() {});
  }

  /// Optimistic UI; persists to `tattsagram_likes` (triggers maintain `likes_count`).
  void _onToggleLike(TattsagramPost post) {
    final key = _likeDedupeKey(post);
    if (_likePersistInFlight.contains(key)) return;

    final wasLiked = post.isLikedByMe;
    final serverId = post.id;
    final hasServerRow = serverId != null && serverId.isNotEmpty;

    if (!hasServerRow) {
      _applyOptimisticLike(post, wasLiked: wasLiked);
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
    final next = externalAllows && _snapPlaybackEnabled;
    if (_feedPlaybackGate.value != next) {
      _feedPlaybackGate.value = next;
    }
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
      _onFeedScrollSoundPass();
      // Extra pass helps when scroll metrics update one frame later.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onFeedScrollSoundPass();
      });
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
          TattsagramPost(
            mediaUrl: videoUrl,
            mediaType: TattsagramMediaType.video,
            artistName: artistName,
            location: '',
            caption: '',
            timestamp: DateTime.now(),
            isUploading: false,
            uploadProgress: 1.0,
            videoUrl: videoUrl,
          ),
        );
      }
      _chatPosts.removeWhere((p) => p.isUploading);
      _mergeUniquePoolFromSources();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rebuildRankedSequencePreservingAnchor();
    });
  }

  void _onPhotoPostedFromLiveChat(TattsagramPost post) {
    setState(() {
      final pid = post.id;
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
      _mergeUniquePoolFromSources();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rebuildRankedSequencePreservingAnchor();
    });
  }

  void _onPendingVideoUploadFailed(String localTempPostId) {
    setState(() {
      _chatPosts.removeWhere((p) => p.id == localTempPostId);
      _mergeUniquePoolFromSources();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rebuildRankedSequencePreservingAnchor();
    });
  }

  Widget _buildFeed() {
    if (!_remoteLoadDone) {
      return const Center(child: CircularProgressIndicator());
    }
    final seq = _feedSequence;
    final L = seq.length;
    if (L == 0) {
      return const Center(
        child: Text('No Tattsagram posts yet'),
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
          _onFeedScrollSoundPass();
          TattsagramVideoSoundRegistry.scheduleFinalizeSoundPass();
        },
        itemBuilder: (context, index) {
          final p = seq[index];
          final isActive = index == _currentIndex;
          final mountDecoder =
              isActive && p.mediaType == TattsagramMediaType.video;
          return _TattsagramFeedItem(
            key: ValueKey('tt-$index-${p.id ?? p.canonicalRemoteUrl}'),
            post: p,
            isCenter: isActive,
            mountVideoDecoder: mountDecoder,
            onVideoSurfaceTap: null,
            onVideoThumbnailTap: p.mediaType == TattsagramMediaType.video
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
        _onFeedScrollSoundPass();
        TattsagramVideoSoundRegistry.scheduleFinalizeSoundPass();
      },
      itemBuilder: (context, index) {
        final p = seq[index];
        return _TattsagramFeedItem(
          key:
              ValueKey('${p.id ?? p.canonicalRemoteUrl}-${p.mediaType}-$index'),
          post: p,
          isCenter: index == _currentIndex,
          mountVideoDecoder: p.mediaType == TattsagramMediaType.video,
          onVideoSurfaceTap: p.mediaType == TattsagramMediaType.video
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
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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
                      if (_showBackFab) ...[
                        const SizedBox(height: 8),
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
                      ],
                    ],
                  ),
                ),
              ),
            if (!_isTikTokFullscreen && !_chatOpen)
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  minimum: const EdgeInsets.only(top: 8, right: 8),
                  child: Material(
                    elevation: 2,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.95),
                    child: IconButton(
                      tooltip: 'Live chat',
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () => setState(() => _chatOpen = true),
                    ),
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
      return Image.network(
        thumb,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (_, __, ___) => _fallback,
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
    required this.post,
    required this.isCenter,
    required this.mountVideoDecoder,
    this.onVideoSurfaceTap,
    this.onVideoThumbnailTap,
    required this.centerPlaybackListenable,
    required this.soundMutedListenable,
    required this.onLike,
  });

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
        return VideoPlayerWidget(
          (post.videoUrl ?? post.mediaUrl).trim(),
          filePath: post.localVideo,
          thumbnailUrl: post.thumbnailUrl,
          soundSlotId: post.id ?? post.canonicalRemoteUrl,
          feedPlaybackListenable: isCenter
              ? centerPlaybackListenable
              : const AlwaysStoppedAnimation<bool>(false),
          soundMutedListenable: soundMutedListenable,
          onSurfaceTap: onVideoSurfaceTap,
        );
      }
      return _TattsagramVideoThumbnailOnly(post: post, scheme: scheme);
    }
    return Image.network(
      post.mediaUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator()),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final media = _media(scheme);
    final mediaWithGestures = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onVideoThumbnailTap,
      onDoubleTap: onLike,
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
                      onTap: () => sharePost({'id': post.id}),
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
