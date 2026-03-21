import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models/tattoo_request.dart';
import '../core/services/online_presence_service.dart';
import '../core/services/profile_service.dart';
import 'bid_detail_page.dart';
import 'explore_page.dart';
import 'bid_page.dart';
import 'add_page.dart';
import 'chat_page.dart';
import 'profile_page.dart';
import 'public_artist_profile_page.dart';

/// Main shell with bottom tab bar. Shows 5 tabs: Explore, Bid, Add, Chat, Profile.
/// Add (plus) button is only shown to customers; tattoo artists cannot upload.
class MainShellPage extends StatefulWidget {
  const MainShellPage({
    super.key,
    this.openChatOnLaunch = false,
    this.initialChatReceiverId,
    this.openWinnerProfileOnLaunch = false,
  });

  /// After Stripe deposit payment, open the Chat tab (see [CheckoutSuccessPage]).
  final bool openChatOnLaunch;
  final String? initialChatReceiverId;

  /// After Stripe deposit, open the winning artist’s profile (see [CheckoutSuccessPage]).
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
        // Chat tab: index 3 for customers (5 tabs), index 2 for artists (4 tabs).
        _currentIndex = _isCustomer ? 3 : 2;
      }
    });
    _maybeOpenWinnerProfile();
  }

  /// Pushes the bid winner’s public profile after the user returns from Stripe (e.g. “Open in app”).
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
          builder: (_) => const BidPage(),
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

  List<BottomNavigationBarItem> get _navItems {
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.search),
        label: 'Explore',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.gavel),
        label: 'Bid',
      ),
      if (_isCustomer)
        const BottomNavigationBarItem(
          icon: Icon(Icons.add_circle, size: 36),
          label: 'Upload',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.chat),
        label: 'Chat',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];
    return items;
  }

  /// Switches to Explore tab and triggers a refresh (e.g. after submitting a request).
  void switchToExploreAndRefresh() {
    setState(() => _currentIndex = 0);
    _exploreRefreshTrigger.value++;
  }

  /// Switches to Bid tab and pushes BidDetailPage.
  /// When user taps back, pops and switches to Explore tab.
  void _navigateToBidTab(TattooRequest request) {
    setState(() => _currentIndex = 1);
    _navKeys[1]
        .currentState
        ?.push(
          MaterialPageRoute<void>(
            builder: (_) => BidDetailPage(
              request: request,
              userType: _userType,
            ),
          ),
        )
        .then((_) {
      if (mounted) setState(() => _currentIndex = 0);
    });
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _exploreRefreshTrigger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_profileLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex.clamp(0, _pages.length - 1),
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _currentIndex.clamp(0, _navItems.length - 1),
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          items: _navItems,
        ),
      ),
    );
  }
}
