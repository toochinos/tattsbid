import 'dart:async';

import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../core/models/tattoo_request.dart';
import '../core/services/message_indicator_service.dart';
import '../core/services/online_presence_service.dart';
import '../core/services/profile_service.dart';
import 'artists_page.dart';
import 'bid_detail_page.dart';
import 'explore_page.dart';
import 'add_page.dart';
import 'chat_page.dart';
import 'destination_page.dart';
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
    this.refreshExploreOnLaunch = false,
  });

  /// After Stripe deposit payment, open the Chat tab with the artist (see [CheckoutSuccessPage]).
  final bool openChatOnLaunch;
  final String? initialChatReceiverId;

  /// Optional: push the winning artist’s profile on launch (e.g. deep links).
  final bool openWinnerProfileOnLaunch;

  /// After deposit, reload Explore so request cards show updated status.
  final bool refreshExploreOnLaunch;

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
    if (widget.refreshExploreOnLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _exploreRefreshTrigger.value++;
      });
    }
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

  void _openSettings() {
    Navigator.of(context, rootNavigator: true).pushNamed(AppRoutes.settings);
  }

  Future<void> _openGlobe() async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const DestinationPage(),
      ),
    );
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
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex.clamp(0, _pages.length - 1),
            children: _pages,
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              minimum: const EdgeInsets.only(top: 6, right: 8),
              child: _GlobalTopRightActions(
                onGlobeTap: _openGlobe,
                onSettingsTap: _openSettings,
              ),
            ),
          ),
        ],
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

class _GlobalTopRightActions extends StatelessWidget {
  const _GlobalTopRightActions({
    required this.onGlobeTap,
    required this.onSettingsTap,
  });

  final VoidCallback onGlobeTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TopActionButton(
          tooltip: 'Explore',
          icon: Icons.public,
          onTap: onGlobeTap,
          background: scheme.surface,
        ),
        const SizedBox(width: 8),
        _TopActionButton(
          tooltip: 'Settings',
          icon: Icons.settings,
          onTap: onSettingsTap,
          background: scheme.surface,
        ),
      ],
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    required this.background,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(12),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
  }
}

/// Tattoo machine icon for Artists tab.
class _ArtistsTabIcon extends StatelessWidget {
  const _ArtistsTabIcon({required this.selected});

  final bool selected;
  static const String _asset = 'assets/icons/tattoo.png';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: selected ? 1 : (isDark ? 0.75 : 0.62),
      child: SizedBox(
        width: 30,
        height: 30,
        child: Image.asset(
          _asset,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          color: isDark ? Colors.white : Colors.black,
          colorBlendMode: BlendMode.srcIn,
          errorBuilder: (_, __, ___) => Icon(
            Icons.brush_outlined,
            size: 24,
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
