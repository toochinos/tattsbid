import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/models/tattsagram_post.dart';
import '../widgets/tattsagram_chat_overlay.dart';

/// Social-style vertical feed of tattoo posts (minimal UI).
class TattsagramPage extends StatefulWidget {
  const TattsagramPage({super.key, this.onLeaveFullScreen});

  /// When set (e.g. from [MainShellPage] full-screen mode), shown as AppBar back control.
  final VoidCallback? onLeaveFullScreen;

  @override
  State<TattsagramPage> createState() => _TattsagramPageState();
}

class _TattsagramPageState extends State<TattsagramPage>
    with SingleTickerProviderStateMixin {
  bool _chatOpen = false;

  /// Feed items; user posts from live chat are inserted at the front.
  late List<TattsagramPost> _feedPosts;

  late final ScrollController _feedScrollController;
  Ticker? _autoScrollTicker;
  Duration? _lastTickElapsed;

  /// True while the user is dragging or after a fling until scrolling settles.
  bool _userGestureDrivingScroll = false;

  /// Shown when [_mockPosts] is empty so the loop still has images.
  static final List<TattsagramPost> _placeholderLoopPosts = [
    TattsagramPost(
      imageUrl: 'https://picsum.photos/seed/tattsagram_loop1/1080/1080',
      artistName: 'Tattsagram',
      location: '',
      caption: '',
      timestamp: DateTime(2026, 1, 1),
    ),
    TattsagramPost(
      imageUrl: 'https://picsum.photos/seed/tattsagram_loop2/1080/1080',
      artistName: 'Tattsagram',
      location: '',
      caption: '',
      timestamp: DateTime(2026, 1, 1),
    ),
    TattsagramPost(
      imageUrl: 'https://picsum.photos/seed/tattsagram_loop3/1080/1080',
      artistName: 'Tattsagram',
      location: '',
      caption: '',
      timestamp: DateTime(2026, 1, 1),
    ),
  ];

  static final List<TattsagramPost> _mockPosts = [
    TattsagramPost(
      imageUrl: 'https://picsum.photos/seed/tattsagram1/1080/1080',
      artistName: 'Alex Ink',
      location: 'Melbourne, Australia',
      caption: 'Fine line floral sleeve — session 2.',
      timestamp: DateTime(2026, 4, 8, 14, 30),
    ),
    TattsagramPost(
      imageUrl: 'https://picsum.photos/seed/tattsagram2/1080/1080',
      artistName: 'Studio Nusa',
      location: 'Bali, Indonesia',
      caption: 'Traditional meets modern. Booking open April.',
      timestamp: DateTime(2026, 4, 9, 9, 15),
    ),
    TattsagramPost(
      imageUrl: 'https://picsum.photos/seed/tattsagram3/1080/1080',
      artistName: 'River City Tattoos',
      location: 'Phnom Penh, Cambodia',
      caption: 'Healed blackwork geometric piece.',
      timestamp: DateTime(2026, 4, 10, 18, 0),
    ),
  ];

  List<TattsagramPost> get _loopPosts =>
      _feedPosts.isNotEmpty ? _feedPosts : _placeholderLoopPosts;

  static const int _loopItemMultiplier = 400;

  /// Slow auto-advance; pauses while [_userGestureDrivingScroll] is true.
  static const double _autoScrollPixelsPerSecond = 14;

  @override
  void initState() {
    super.initState();
    _feedPosts = List<TattsagramPost>.from(_mockPosts);
    _feedScrollController = ScrollController();
    _feedScrollController.addListener(_repositionInfiniteScroll);
    _autoScrollTicker = createTicker(_onAutoScrollTick)..start();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _seedLoopScrollOffset());
  }

  @override
  void dispose() {
    _autoScrollTicker?.dispose();
    _feedScrollController
      ..removeListener(_repositionInfiniteScroll)
      ..dispose();
    super.dispose();
  }

  double _itemExtentForWidth(double width) => width;

  void _seedLoopScrollOffset() {
    final c = _feedScrollController;
    if (!mounted || !c.hasClients) return;
    final w = MediaQuery.sizeOf(context).width;
    final n = _loopPosts.length;
    if (w <= 0 || n == 0) return;
    final cycle = n * w;
    c.jumpTo(cycle * 100);
  }

  void _repositionInfiniteScroll() {
    final c = _feedScrollController;
    if (!mounted || !c.hasClients) return;
    final w = MediaQuery.sizeOf(context).width;
    final n = _loopPosts.length;
    if (w <= 0 || n == 0) return;
    final cycle = n * w;
    final o = c.offset;
    if (o < cycle * 8) {
      c.jumpTo(o + cycle * 120);
    } else if (o > cycle * (_loopItemMultiplier - 12)) {
      c.jumpTo(o - cycle * 120);
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
      _feedPosts.insert(0, post);
    });
  }

  Widget _buildFeed() {
    final posts = _loopPosts;
    final n = posts.length;
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
            itemCount: n * _loopItemMultiplier,
            itemBuilder: (context, index) {
              final p = posts[index % n];
              return _TattsagramFeedItem(post: p);
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
      body: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: _buildFeed(),
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
  const _TattsagramFeedItem({required this.post});

  final TattsagramPost post;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            post.imageUrl,
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
