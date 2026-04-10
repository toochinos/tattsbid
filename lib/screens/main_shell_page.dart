import 'dart:async';

import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../core/startup/post_dashboard_onboarding.dart';
import '../core/models/tattoo_request.dart';
import '../core/services/message_indicator_service.dart';
import '../core/services/online_presence_service.dart';
import '../core/services/profile_service.dart';
import '../l10n/app_localizations.dart';
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
/// Upload appears only when the customer is on Explore scoped to Australia, Cambodia, or
/// Indonesia (not worldwide or other destinations), or while they are on the Add tab.
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
  static const Set<String> _exploreCountryNames = {
    'Australia',
    'Cambodia',
    'Indonesia',
    'Thailand',
    'Vietnam',
  };

  /// Explore feeds where customers may upload (globe scope must match exactly).
  static const Set<String> _uploadAllowedExploreCountries = {
    'Australia',
    'Cambodia',
    'Indonesia',
  };

  int _currentIndex = 0;
  final ValueNotifier<int> _exploreRefreshTrigger = ValueNotifier(0);

  /// Bumped when the Message tab is tapped so [ChatPage] returns to the inbox list.
  final ValueNotifier<int> _messageInboxResetTrigger = ValueNotifier(0);
  String? _userType;
  bool _profileLoaded = false;
  Timer? _presenceTimer;
  bool _didPushWinnerProfile = false;

  /// Country tag for new posts (profile + globe). Not the same as the Explore list scope.
  final ValueNotifier<String> _postCountryNotifier =
      ValueNotifier<String>('Indonesia');

  /// Null = main Explore (all countries, title "Explore"). Non-null = globe destination feed.
  final ValueNotifier<String?> _exploreFeedScopeNotifier =
      ValueNotifier<String?>(null);
  bool _exploreCountryLockedByPicker = false;

  /// Avoid rebuilding [Navigator] widgets every [setState] — keeps tab stacks stable.
  List<Widget>? _memoTabPages;
  bool? _memoIsCustomer;

  @override
  void initState() {
    super.initState();
    PostDashboardOnboarding.scheduleAfterFirstFrame();
    _loadProfile();
    OnlinePresenceService.updatePresence();
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      OnlinePresenceService.updatePresence();
    });
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.getCurrentProfile();
    if (!mounted) return;
    final wasCustomer = _userType == 'customer';
    setState(() {
      _userType = profile?.userType;
      _profileLoaded = true;
      if (!_exploreCountryLockedByPicker) {
        final c = profile?.country?.trim();
        if (c != null && c.isNotEmpty && _exploreCountryNames.contains(c)) {
          _postCountryNotifier.value = c;
        }
      }
      if (_memoTabPages != null && wasCustomer != _isCustomer) {
        _memoTabPages = null;
        _memoIsCustomer = null;
      }
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

  bool get _exploreScopeAllowsCustomerUpload {
    final scope = _exploreFeedScopeNotifier.value;
    return scope != null && _uploadAllowedExploreCountries.contains(scope);
  }

  /// Upload tab: customers only, and only for AU/KH/ID Explore (or while on Add stack).
  bool get _showCustomerUploadInBar =>
      _isCustomer &&
      ((_currentIndex == 0 && _exploreScopeAllowsCustomerUpload) ||
          _currentIndex == 2);

  /// Bottom bar index → [IndexedStack] index (skips Add when upload tab is omitted).
  int _stackIndexFromBarIndex(int barIndex) {
    if (!_isCustomer) return barIndex;
    if (!_showCustomerUploadInBar) {
      return switch (barIndex) {
        0 => 0,
        1 => 1,
        2 => 3,
        3 => 4,
        _ => barIndex.clamp(0, 4),
      };
    }
    return barIndex;
  }

  /// [IndexedStack] index → bottom bar selected index (inverse of [_stackIndexFromBarIndex]).
  int _barIndexFromStack(int stackIndex) {
    if (!_isCustomer) return stackIndex;
    if (!_showCustomerUploadInBar) {
      return switch (stackIndex) {
        0 => 0,
        1 => 1,
        3 => 2,
        4 => 3,
        _ => stackIndex.clamp(0, 3),
      };
    }
    return stackIndex;
  }

  List<Widget> _buildTabPages() {
    final pages = <Widget>[
      Navigator(
        key: _navKeys[0],
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => ExplorePage(
            refreshTrigger: _exploreRefreshTrigger,
            userType: _userType,
            exploreFeedScopeNotifier: _exploreFeedScopeNotifier,
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
            builder: (_) => AddPage(
              selectedExploreCountryNotifier: _postCountryNotifier,
              onRequestSubmitted: switchToExploreAndRefresh,
            ),
          ),
        ),
      );
    }
    final profileTabIndex = _isCustomer ? 4 : 3;
    pages.addAll([
      Navigator(
        key: _navKeys[_isCustomer ? 3 : 2],
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => ChatPage(
            initialReceiverId: widget.initialChatReceiverId,
            inboxResetTrigger: _messageInboxResetTrigger,
          ),
        ),
      ),
      Navigator(
        key: _navKeys[profileTabIndex],
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => ProfilePage(
            onProfileUpdated: () {
              _loadProfile();
              setState(() => _currentIndex = profileTabIndex);
            },
          ),
        ),
      ),
    ]);
    return pages;
  }

  List<Widget> _tabPagesForIndexedStack() {
    if (_memoTabPages != null && _memoIsCustomer == _isCustomer) {
      return _memoTabPages!;
    }
    _memoIsCustomer = _isCustomer;
    _memoTabPages = _buildTabPages();
    return _memoTabPages!;
  }

  static final List<GlobalKey<NavigatorState>> _navKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  List<BottomNavigationBarItem> _navItems(
    BuildContext context,
    bool showEnvelope,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: const Icon(Icons.search),
        label: l10n.tabExplore,
      ),
      BottomNavigationBarItem(
        icon: const _ArtistsTabIcon(selected: false),
        activeIcon: const _ArtistsTabIcon(selected: true),
        label: l10n.tabArtists,
      ),
      if (_showCustomerUploadInBar)
        BottomNavigationBarItem(
          icon: const Icon(Icons.add_circle, size: 36),
          label: l10n.tabUpload,
        ),
      BottomNavigationBarItem(
        icon: _MessageTabIconWithEnvelope(showEnvelope: showEnvelope),
        label: l10n.tabMessage,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person),
        label: l10n.tabProfile,
      ),
    ];
    return items;
  }

  /// Switches to Explore scoped to the post country and refreshes (after submitting a request).
  void switchToExploreAndRefresh() {
    final c = _postCountryNotifier.value.trim();
    _exploreFeedScopeNotifier.value = c.isNotEmpty ? c : null;
    setState(() => _currentIndex = 0);
    _popTabNavigatorToRoot(0);
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

  /// Bottom bar taps always show that tab’s root screen (pop nested routes).
  void _popTabNavigatorToRoot(int tabIndex) {
    void popNested() {
      _navKeys[tabIndex].currentState?.popUntil((route) => route.isFirst);
    }

    popNested();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      popNested();
    });
  }

  /// Tab taps: pop nested routes; Artists/Message also dismiss one root overlay.
  /// Message: [ChatPage] uses in-page state for threads — [_messageInboxResetTrigger]
  /// forces return to the inbox list (same as the in-chat back button).
  void _onBottomNavTap(int index) {
    if (index == 0) {
      _exploreFeedScopeNotifier.value = null;
    }
    setState(() => _currentIndex = index);
    _popTabNavigatorToRoot(index);
    final messageTabIndex = _isCustomer ? 3 : 2;
    if (index == messageTabIndex) {
      _messageInboxResetTrigger.value++;
    }
    if (index == 1 || index == messageTabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final root = Navigator.of(context, rootNavigator: true);
        if (root.canPop()) {
          root.pop();
        }
      });
    }
  }

  Future<void> _openGlobe() async {
    final selected =
        await Navigator.of(context, rootNavigator: true).push<String?>(
      MaterialPageRoute<String?>(
        builder: (_) => const DestinationPage(),
      ),
    );
    if (!mounted || selected == null || selected.isEmpty) return;
    _postCountryNotifier.value = selected;
    _exploreFeedScopeNotifier.value = selected;
    _exploreCountryLockedByPicker = true;
    setState(() => _currentIndex = 0);
    _popTabNavigatorToRoot(0);
    _exploreRefreshTrigger.value++;
  }

  @override
  void dispose() {
    MessageIndicatorService.stop();
    _presenceTimer?.cancel();
    _postCountryNotifier.dispose();
    _exploreFeedScopeNotifier.dispose();
    _exploreRefreshTrigger.dispose();
    _messageInboxResetTrigger.dispose();
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

    final tabPages = _tabPagesForIndexedStack();
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex.clamp(0, tabPages.length - 1),
            children: tabPages,
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              minimum: const EdgeInsets.only(top: 6, right: 8),
              child: _GlobalTopRightActions(
                l10n: AppLocalizations.of(context)!,
                onGlobeTap: _openGlobe,
                onSettingsTap: _openSettings,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: ValueListenableBuilder<String?>(
          valueListenable: _exploreFeedScopeNotifier,
          builder: (context, _, __) {
            return ValueListenableBuilder<bool>(
              valueListenable: MessageIndicatorService.hasUnread,
              builder: (context, showEnvelope, _) {
                final items = _navItems(context, showEnvelope);
                final stackIndex = _currentIndex.clamp(0, tabPages.length - 1);
                final barIndex =
                    _barIndexFromStack(stackIndex).clamp(0, items.length - 1);
                return BottomNavigationBar(
                  currentIndex: barIndex,
                  onTap: (barIndex) {
                    final stack = _stackIndexFromBarIndex(barIndex);
                    _onBottomNavTap(stack);
                  },
                  // Do not call [MessageIndicatorService.refresh] here — it would
                  // clear the green envelope as soon as the tab is opened, before
                  // the user reads or replies. Updates come from realtime, polling,
                  // and [ChatPage] after send/mark-read.
                  type: BottomNavigationBarType.fixed,
                  items: items,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _GlobalTopRightActions extends StatelessWidget {
  const _GlobalTopRightActions({
    required this.l10n,
    required this.onGlobeTap,
    required this.onSettingsTap,
  });

  final AppLocalizations l10n;
  final VoidCallback onGlobeTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TopActionButton(
          tooltip: l10n.actionTooltipExplore,
          icon: Icons.public,
          onTap: onGlobeTap,
          background: scheme.surface,
        ),
        const SizedBox(width: 8),
        _TopActionButton(
          tooltip: l10n.actionTooltipSettings,
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
