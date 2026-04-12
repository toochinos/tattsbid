import 'dart:async';

import 'package:flutter/animation.dart'; // ignore: unnecessary_import
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/tattsagram_post.dart';
import '../core/services/tattsagram_like_service.dart';
import '../core/services/tattsagram_post_service.dart';
import '../core/services/tattsagram_ranked_pool_feed.dart';
import '../core/services/tattsagram_video_sound_registry.dart';
import '../widgets/tattsagram_chat_overlay.dart';
import '../widgets/video_player_widget.dart';

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

class _TattsagramPageState extends State<TattsagramPage>
    with SingleTickerProviderStateMixin {
  /// Open on entry so users immediately see Live Chat, composer, and camera affordances.
  bool _chatOpen = true;

  /// Unique posts (pool). Ranked expansion uses [TattsagramRankedPoolFeed.score].
  late List<TattsagramPost> _uniquePool;

  /// Shuffled expanded sequence: `score` copies per post, shuffled once per rebuild.
  late List<TattsagramPost> _feedSequence;

  /// After a like: weights change but sequence is not rebuilt until [near-end] load.
  bool _needsSequenceRebuild = false;

  late final ScrollController _feedScrollController;
  Ticker? _autoScrollTicker;
  Duration? _lastTickElapsed;

  /// True while the user is dragging or after a fling until scrolling settles.
  bool _userGestureDrivingScroll = false;

  static const int _nearEndSlots = 10;

  /// Latest rows from Supabase `tattsagram_post`.
  List<TattsagramPost> _remotePosts = [];

  /// Live-chat uploads until the same [mediaUrl] exists in [_remotePosts].
  final List<TattsagramPost> _chatPosts = [];

  /// False until the first remote fetch attempt finishes (success or error).
  bool _remoteLoadDone = false;

  /// Dedupes concurrent like/unlike calls per post (id or mediaUrl for chat-only).
  final Set<String> _likePersistInFlight = {};

  static const int _loopItemMultiplier = 400;

  /// Slow auto-advance; pauses while [_userGestureDrivingScroll] is true.
  static const double _autoScrollPixelsPerSecond = 14;

  @override
  void initState() {
    super.initState();
    _uniquePool = [];
    _feedSequence = [];
    _recomposeFeedAndWeights();
    _feedScrollController = ScrollController();
    _feedScrollController.addListener(_onFeedScrollCombined);
    _autoScrollTicker = createTicker(_onAutoScrollTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadRemoteTattsagramPosts());
    });
  }

  void _mergeUniquePoolFromSources() {
    final remoteUrls = _remotePosts.map((p) => p.mediaUrl).toSet();
    final chat = _chatPosts
        .where((p) => !remoteUrls.contains(p.mediaUrl))
        .toList(growable: false);
    _uniquePool = [...chat, ..._remotePosts];
  }

  /// Rebuilds [_uniquePool] from chat + remote and reshuffles the ranked expanded sequence.
  void _recomposeFeedAndWeights() {
    _mergeUniquePoolFromSources();
    _feedSequence =
        TattsagramRankedPoolFeed.buildShuffledRankedSequence(_uniquePool);
    _needsSequenceRebuild = false;
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
    _autoScrollTicker?.dispose();
    _feedScrollController
      ..removeListener(_onFeedScrollCombined)
      ..dispose();
    super.dispose();
  }

  int get _sequenceLength => _feedSequence.length;

  void _onFeedScrollCombined() {
    _onFeedScrollSoundPass();
    _repositionInfiniteScroll();
    _maybeRebuildRankedSequenceNearEnd();
  }

  double _itemExtentForWidth(double width) => width;

  void _onFeedScrollSoundPass() {
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

    final w = _itemExtentForWidth(MediaQuery.sizeOf(context).width);
    final oldL = _feedSequence.length;

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
      (post.id != null && post.id!.isNotEmpty) ? post.id! : post.mediaUrl;

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

  void _onAutoScrollTick(Duration elapsed) {
    _lastTickElapsed ??= elapsed;
    final dt = (elapsed - _lastTickElapsed!).inMicroseconds / 1e6;
    _lastTickElapsed = elapsed;
    if (!mounted ||
        !_feedScrollController.hasClients ||
        _userGestureDrivingScroll ||
        dt <= 0) {
      return;
    }
    final next = _feedScrollController.offset + _autoScrollPixelsPerSecond * dt;
    final max = _feedScrollController.position.maxScrollExtent;
    _feedScrollController.jumpTo(next.clamp(0.0, max));
  }

  void _onPhotoPostedFromLiveChat(TattsagramPost post) {
    setState(() {
      _chatPosts.insert(0, post);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final extent = _itemExtentForWidth(w);
        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification n) {
            if (n is ScrollStartNotification && n.dragDetails != null) {
              _userGestureDrivingScroll = true;
            } else if (n is ScrollEndNotification) {
              _userGestureDrivingScroll = false;
            }
            return false;
          },
          child: ListView.builder(
            controller: _feedScrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemExtent: extent,
            itemCount: L * _loopItemMultiplier,
            itemBuilder: (context, index) {
              final p = seq[index % L];
              return _TattsagramFeedItem(
                key: ValueKey('${p.id ?? p.mediaUrl}-${p.mediaType}-$index'),
                post: p,
                soundSlotId: index,
                scrollController: _feedScrollController,
                feedPlaybackListenable: widget.feedPlaybackListenable,
                onLike: () => _onToggleLike(p),
              );
            },
          ),
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

    return Scaffold(
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
          if (_showBackFab && !_chatOpen)
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                minimum: const EdgeInsets.only(top: 8, left: 8),
                child: Material(
                  elevation: 2,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
                  child: IconButton(
                    tooltip: backTooltip,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _handleBack,
                  ),
                ),
              ),
            ),
          if (!_chatOpen)
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                minimum: const EdgeInsets.only(top: 8, right: 8),
                child: Material(
                  elevation: 2,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
                  child: IconButton(
                    tooltip: 'Live chat',
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () => setState(() => _chatOpen = true),
                  ),
                ),
              ),
            ),
          TattsagramChatOverlay(
            isOpen: _chatOpen,
            onClose: () => setState(() => _chatOpen = false),
            onPhotoPostedToFeed: _onPhotoPostedFromLiveChat,
            showComposerBack: _showBackFab,
            onComposerBack: _handleBack,
          ),
        ],
      ),
    );
  }
}

class _TattsagramFeedItem extends StatelessWidget {
  const _TattsagramFeedItem({
    super.key,
    required this.post,
    required this.soundSlotId,
    required this.scrollController,
    this.feedPlaybackListenable,
    required this.onLike,
  });

  final TattsagramPost post;
  final int soundSlotId;
  final ScrollController scrollController;
  final ValueListenable<bool>? feedPlaybackListenable;
  final VoidCallback onLike;

  Widget _media(ColorScheme scheme) {
    if (post.mediaType == TattsagramMediaType.video) {
      return VideoPlayerWidget(
        post.mediaUrl,
        soundSlotId: soundSlotId,
        scrollController: scrollController,
        feedPlaybackListenable: feedPlaybackListenable,
      );
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
    final likes = post['likes_count'] ?? 0;

    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: onLike,
            child: media,
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onLike,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            post.isLikedByMe
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.white,
                            size: 28,
                          ),
                          Text(
                            '$likes',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
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
