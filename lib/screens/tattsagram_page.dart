import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/models/tattsagram_post.dart';
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

  /// Shown when [_uniquePool] is empty so the loop still has images.
  static final List<TattsagramPost> _placeholderLoopPosts = [
    TattsagramPost(
      id: 'ph_0',
      mediaUrl: 'https://picsum.photos/seed/tattsagram_loop1/1080/1080',
      artistName: 'Tattsagram',
      location: '',
      caption: '',
      timestamp: DateTime(2026, 1, 1),
      likesCount: 0,
    ),
    TattsagramPost(
      id: 'ph_1',
      mediaUrl: 'https://picsum.photos/seed/tattsagram_loop2/1080/1080',
      artistName: 'Tattsagram',
      location: '',
      caption: '',
      timestamp: DateTime(2026, 1, 1),
      likesCount: 0,
    ),
    TattsagramPost(
      id: 'ph_2',
      mediaUrl: 'https://picsum.photos/seed/tattsagram_loop3/1080/1080',
      artistName: 'Tattsagram',
      location: '',
      caption: '',
      timestamp: DateTime(2026, 1, 1),
      likesCount: 0,
    ),
  ];

  /// Demo pool: distinct [likesCount] → different weights (5+1, 1+1, 3+1).
  static final List<TattsagramPost> _mockPosts = [
    TattsagramPost(
      id: 'mock_a',
      mediaUrl: 'https://picsum.photos/seed/tattsagram1/1080/1080',
      artistName: 'Alex Ink',
      location: 'Melbourne, Australia',
      caption: 'Fine line floral sleeve — session 2.',
      timestamp: DateTime(2026, 4, 8, 14, 30),
      likesCount: 5,
    ),
    TattsagramPost(
      id: 'mock_b',
      mediaUrl: 'https://picsum.photos/seed/tattsagram2/1080/1080',
      artistName: 'Studio Nusa',
      location: 'Bali, Indonesia',
      caption: 'Traditional meets modern. Booking open April.',
      timestamp: DateTime(2026, 4, 9, 9, 15),
      likesCount: 1,
    ),
    TattsagramPost(
      id: 'mock_c',
      mediaUrl: 'https://picsum.photos/seed/tattsagram3/1080/1080',
      artistName: 'River City Tattoos',
      location: 'Phnom Penh, Cambodia',
      caption: 'Healed blackwork geometric piece.',
      timestamp: DateTime(2026, 4, 10, 18, 0),
      likesCount: 3,
    ),
  ];

  List<TattsagramPost> get _activeUniquePool =>
      _uniquePool.isNotEmpty ? _uniquePool : _placeholderLoopPosts;

  static const int _loopItemMultiplier = 400;

  /// Slow auto-advance; pauses while [_userGestureDrivingScroll] is true.
  static const double _autoScrollPixelsPerSecond = 14;

  @override
  void initState() {
    super.initState();
    _uniquePool = List<TattsagramPost>.from(_mockPosts);
    _feedSequence =
        TattsagramRankedPoolFeed.buildShuffledRankedSequence(_activeUniquePool);
    _feedScrollController = ScrollController();
    _feedScrollController.addListener(_onFeedScrollCombined);
    _autoScrollTicker = createTicker(_onAutoScrollTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedLoopScrollOffset();
      TattsagramVideoSoundRegistry.beginScrollSoundPass();
      TattsagramVideoSoundRegistry.scheduleFinalizeSoundPass();
    });
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
        TattsagramRankedPoolFeed.buildShuffledRankedSequence(_activeUniquePool);
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

  /// Local like toggle (demo). Updates pool + in-place sequence refs; defers reshuffle.
  void _onToggleLike(TattsagramPost post) {
    final wasLiked = post.isLikedByMe;
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
      _uniquePool.insert(0, post);
    });
    _rebuildRankedSequencePreservingAnchor();
  }

  Widget _buildFeed() {
    final seq = _feedSequence;
    final L = seq.length;
    if (L == 0) {
      return const Center(child: Text('No posts'));
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
                            '${post.likesCount}',
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
