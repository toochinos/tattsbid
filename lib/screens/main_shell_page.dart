import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models/tattoo_request.dart';
import '../core/services/message_indicator_service.dart';
import '../core/services/online_presence_service.dart';
import '../core/services/profile_service.dart';
import 'artists_page.dart';
import 'bid_detail_page.dart';
import 'explore_page.dart';
import 'add_page.dart';
import 'chat_page.dart';
import 'profile_page.dart';
import 'public_artist_profile_page.dart';

/// Main shell with bottom tab bar: Explore, Artists, Add (customers), Message, Profile.
/// Bidding is opened from Explore → request detail ([BidDetailPage]), not a root tab.
/// Message tab is 1:1 between tattoo artists and customers only.
/// Add (plus) is only for customers; tattoo artists cannot upload.
class MainShellPage extends StatefulWidget {
  const MainShellPage({
    super.key,
    this.openChatOnLaunch = false,
    this.initialChatReceiverId,
    this.openWinnerProfileOnLaunch = false,
  });

  /// After Stripe deposit payment, open the Chat tab with the artist (see [CheckoutSuccessPage]).
  final bool openChatOnLaunch;
  final String? initialChatReceiverId;

  /// Optional: push the winning artist’s profile on launch (e.g. deep links).
  final bool openWinnerProfileOnLaunch;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _currentIndex = 0;
  final ValueNotifier<int> _exploreRefreshTrigger = ValueNotifier(0);
  String? _userType;
  bool _profileLoaded = false;
  Timer? _presenceTimer;
  bool _didPushWinnerProfile = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    OnlinePresenceService.updatePresence();
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      OnlinePresenceService.updatePresence();
    });
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.getCurrentProfile();
    if (!mounted) return;
    setState(() {
      _userType = profile?.userType;
      _profileLoaded = true;
      if (widget.openChatOnLaunch) {
        // Message tab: index 3 for customers (5 tabs), index 2 for artists (4 tabs).
        _currentIndex = _isCustomer ? 3 : 2;
      }
    });
    MessageIndicatorService.start();
    _maybeOpenWinnerProfile();
  }

  /// Pushes the bid winner’s public profile when [openWinnerProfileOnLaunch] is set.
  void _maybeOpenWinnerProfile() {
    if (_didPushWinnerProfile) return;
    if (!widget.openWinnerProfileOnLaunch) return;
    final id = widget.initialChatReceiverId?.trim();
    if (id == null || id.isEmpty) return;
    _didPushWinnerProfile = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PublicArtistProfilePage(userId: id),
        ),
      );
    });
  }

  bool get _isCustomer => _userType == 'customer';

  List<Widget> get _pages {
    final pages = <Widget>[
      Navigator(
        key: _navKeys[0],
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => ExplorePage(
            refreshTrigger: _exploreRefreshTrigger,
            userType: _userType,
            onRequestSelectedForBid: _navigateToBidTab,
          ),
        ),
      ),
      Navigator(
        key: _navKeys[1],
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => const ArtistsPage(),
        ),
      ),
    ];
    if (_isCustomer) {
      pages.add(
        Navigator(
          key: _navKeys[2],
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) =>
                AddPage(onRequestSubmitted: switchToExploreAndRefresh),
          ),
        ),
      );
    }
    pages.addAll([
      Navigator(
        key: _navKeys[_isCustomer ? 3 : 2],
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) =>
              ChatPage(initialReceiverId: widget.initialChatReceiverId),
        ),
      ),
      Navigator(
        key: _navKeys[_isCustomer ? 4 : 3],
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => ProfilePage(
            onProfileUpdated: () {
              _loadProfile();
              setState(() => _currentIndex = _pages.length - 1);
            },
          ),
        ),
      ),
    ]);
    return pages;
  }

  static final List<GlobalKey<NavigatorState>> _navKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  List<BottomNavigationBarItem> _navItems(bool showEnvelope) {
    return <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.search),
        label: 'Explore',
      ),
      const BottomNavigationBarItem(
        icon: _ArtistsTabIcon(selected: false),
        activeIcon: _ArtistsTabIcon(selected: true),
        label: 'Artists',
      ),
      if (_isCustomer)
        const BottomNavigationBarItem(
          icon: Icon(Icons.add_circle, size: 36),
          label: 'Upload',
        ),
      BottomNavigationBarItem(
        icon: _MessageTabIconWithEnvelope(showEnvelope: showEnvelope),
        label: 'Message',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];
  }

  /// Switches to Explore tab and triggers a refresh (e.g. after submitting a request).
  void switchToExploreAndRefresh() {
    setState(() => _currentIndex = 0);
    _exploreRefreshTrigger.value++;
  }

  /// Opens [BidDetailPage] from the Explore stack (no dedicated Bid tab).
  void _navigateToBidTab(TattooRequest request) {
    setState(() => _currentIndex = 0);
    // Refresh profile so [BidDetailPage] has up-to-date role; eligibility also
    // re-fetched there via [BidService.isCurrentUserTattooArtist].
    Future<void>(() async {
      await _loadProfile();
      if (!mounted) return;
      _navKeys[0].currentState?.push(
            MaterialPageRoute<void>(
              builder: (_) => BidDetailPage(
                request: request,
              ),
            ),
          );
    });
  }

  @override
  void dispose() {
    MessageIndicatorService.stop();
    _presenceTimer?.cancel();
    _exploreRefreshTrigger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_profileLoaded) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _currentIndex.clamp(0, _pages.length - 1),
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: MessageIndicatorService.hasUnread,
          builder: (context, showEnvelope, _) {
            final items = _navItems(showEnvelope);
            return BottomNavigationBar(
              currentIndex: _currentIndex.clamp(0, items.length - 1),
              onTap: (index) {
                setState(() => _currentIndex = index);
                // Do not call [MessageIndicatorService.refresh] here — it would
                // clear the green envelope as soon as the tab is opened, before
                // the user reads or replies. Updates come from realtime, polling,
                // and [ChatPage] after send/mark-read.
              },
              type: BottomNavigationBarType.fixed,
              items: items,
            );
          },
        ),
      ),
    );
  }
}

/// Tattoo machine asset for the Artists tab ([assets/tattoo_machine_icon.png]).
///
/// Do **not** use [Image.color] + [BlendMode.srcIn] on full-color PNGs (navy on
/// white) — that flattens the graphic into a solid square. We show the real
/// pixels and only adjust opacity for unselected vs selected.
class _ArtistsTabIcon extends StatelessWidget {
  const _ArtistsTabIcon({required this.selected});

  final bool selected;

  static const String _asset = 'assets/tattoo_machine_icon.png';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: selected ? 1 : 0.55,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Image.asset(
          _asset,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => Icon(
            Icons.brush_outlined,
            size: 30,
            color: selected
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.64),
          ),
        ),
      ),
    );
  }
}

/// Chat icon with optional small green envelope when a thread awaits your reply.
class _MessageTabIconWithEnvelope extends StatelessWidget {
  const _MessageTabIconWithEnvelope({required this.showEnvelope});

  final bool showEnvelope;

  static const Color _envelopeGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          const Icon(Icons.chat, size: 26),
          if (showEnvelope)
            const Positioned(
              right: -4,
              top: -6,
              child: Icon(
                Icons.mail_rounded,
                size: 15,
                color: _envelopeGreen,
                shadows: [
                  Shadow(color: Colors.white, blurRadius: 2),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
