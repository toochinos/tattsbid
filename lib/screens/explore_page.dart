import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/tattoo_request.dart';
import '../core/models/user_profile.dart';
import '../core/services/profile_service.dart';
import '../core/services/tattoo_request_service.dart';
import '../l10n/app_localizations.dart';

/// Explore tab - displays open tattoo requests (photos from customers).
class ExplorePage extends StatefulWidget {
  const ExplorePage({
    super.key,
    this.refreshTrigger,
    this.userType,
    required this.exploreFeedScopeNotifier,
    required this.onRequestSelectedForBid,
  });

  /// When this value changes, the page refetches tattoo requests.
  final ValueListenable<int>? refreshTrigger;

  /// 'tattoo_artist' or 'customer'. Tattoo artists cannot delete explore photos.
  final String? userType;

  /// Null = main Explore (all countries). Non-null = filtered by country (globe).
  final ValueNotifier<String?> exploreFeedScopeNotifier;

  /// When tapping a request, opens bid detail on the Explore stack.
  final void Function(TattooRequest request) onRequestSelectedForBid;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  List<TattooRequest> _requests = [];
  bool _loading = true;
  String? _errorMessage;
  RealtimeChannel? _realtimeChannel;
  Timer? _pollTimer;

  final TextEditingController _searchController = TextEditingController();
  bool _nearMeActive = false;
  UserProfile? _profileForNearMe;

  @override
  void initState() {
    super.initState();
    widget.exploreFeedScopeNotifier.addListener(_onExploreFeedScopeChanged);
    _searchController.addListener(_onSearchTextChanged);
    _loadRequests();
    _refreshProfileForNearMe();
    _subscribeToRealtime();
    _startPollingFallback();
    widget.refreshTrigger?.addListener(_onRefreshTriggered);
  }

  void _onSearchTextChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshProfileForNearMe() async {
    final p = await ProfileService.getCurrentProfile();
    if (!mounted) return;
    setState(() => _profileForNearMe = p);
  }

  Future<void> _onBidsNearMeTap() async {
    final l10n = AppLocalizations.of(context)!;
    if (_nearMeActive) {
      setState(() => _nearMeActive = false);
      return;
    }
    await _refreshProfileForNearMe();
    if (!mounted) return;
    final p = _profileForNearMe;
    final hasSuburb = p?.suburb?.trim().isNotEmpty == true;
    final hasCity = p?.city?.trim().isNotEmpty == true;
    if (!hasSuburb && !hasCity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exploreNearMeNeedProfile)),
      );
      return;
    }
    setState(() => _nearMeActive = true);
  }

  List<TattooRequest> get _visibleRequests {
    var list = List<TattooRequest>.from(_requests);
    if (_nearMeActive) {
      final p = _profileForNearMe;
      final suburb = p?.suburb?.trim().toLowerCase() ?? '';
      final city = p?.city?.trim().toLowerCase() ?? '';
      list = list.where((r) {
        final loc = (r.customerLocation ?? '').toLowerCase();
        if (suburb.isNotEmpty && loc.contains(suburb)) return true;
        if (city.isNotEmpty && loc.contains(city)) return true;
        return false;
      }).toList();
    }
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) {
        final name = (r.customerName ?? '').toLowerCase();
        final loc = (r.customerLocation ?? '').toLowerCase();
        return name.contains(q) || loc.contains(q);
      }).toList();
    }
    return list;
  }

  Widget _buildExploreSearchPill(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF5E6A7A) : const Color(0xFF6B7280);
    final muted = isDark ? const Color(0xFFB0B8C4) : const Color(0xFF4B5563);
    final accent = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border.withValues(alpha: 0.9)),
      ),
      padding: const EdgeInsets.only(left: 4, right: 2, top: 2, bottom: 2),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(Icons.search, size: 22, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: l10n.exploreSearchHint,
                hintStyle: theme.textTheme.bodyLarge?.copyWith(color: muted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: border.withValues(alpha: 0.35),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: _onBidsNearMeTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _nearMeActive ? Icons.close : Icons.location_on_outlined,
                    size: 20,
                    color: _nearMeActive ? accent : muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.exploreBidsNearMe,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: accent,
                      fontWeight:
                          _nearMeActive ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Realtime subscription for instant updates.
  void _subscribeToRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('tattoo_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tattoo_requests',
          callback: (payload) {
            if (!mounted) return;
            if (payload.eventType == PostgresChangeEvent.delete) {
              final id = payload.oldRecord['id'] as String?;
              if (id != null) {
                setState(() {
                  _requests.removeWhere((r) => r.id == id);
                });
              } else {
                _loadRequests();
              }
            } else {
              _loadRequests();
            }
          },
        )
        .subscribe();
  }

  /// Fallback: poll every 20s when Realtime isn't working (e.g. table not in publication).
  void _startPollingFallback() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      _loadRequests(silent: true);
    });
  }

  @override
  void didUpdateWidget(ExplorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTrigger != widget.refreshTrigger) {
      oldWidget.refreshTrigger?.removeListener(_onRefreshTriggered);
      widget.refreshTrigger?.addListener(_onRefreshTriggered);
    }
    if (oldWidget.exploreFeedScopeNotifier != widget.exploreFeedScopeNotifier) {
      oldWidget.exploreFeedScopeNotifier
          .removeListener(_onExploreFeedScopeChanged);
      widget.exploreFeedScopeNotifier.addListener(_onExploreFeedScopeChanged);
      _loadRequests();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    widget.exploreFeedScopeNotifier.removeListener(_onExploreFeedScopeChanged);
    _pollTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    widget.refreshTrigger?.removeListener(_onRefreshTriggered);
    super.dispose();
  }

  void _onExploreFeedScopeChanged() {
    if (!mounted) return;
    _loadRequests();
  }

  void _onRefreshTriggered() {
    _loadRequests();
  }

  void _removeRequest(String id) {
    setState(() {
      _requests.removeWhere((r) => r.id == id);
    });
    // Delay next poll so DB has time to commit before we refetch.
    _pollTimer?.cancel();
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _startPollingFallback();
    });
  }

  Future<void> _loadRequests({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      final scope = widget.exploreFeedScopeNotifier.value?.trim();
      final requests = await TattooRequestService.fetchOpenRequests(
        country: (scope == null || scope.isEmpty) ? null : scope,
      );
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = silent ? _errorMessage : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scope = widget.exploreFeedScopeNotifier.value?.trim();
    final isMainFeed = scope == null || scope.isEmpty;
    return Scaffold(
      appBar: AppBar(
        centerTitle: isMainFeed,
        title: isMainFeed
            ? Text(l10n.exploreTitle)
            : Padding(
                padding: const EdgeInsets.only(right: 96),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.exploreTitleWithCountry(scope),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: _buildExploreSearchPill(l10n),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadRequests,
              child: _buildBody(l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading && _requests.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.32),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_errorMessage != null && _requests.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadRequests,
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (_requests.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noTattooRequestsYet,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.addRequestToSeeHere,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final visible = _visibleRequests;
    if (visible.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.28),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.search_off_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.exploreNoSearchResults,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final request = visible[index];
                return _RequestCard(
                  request: request,
                  currentUserId: Supabase.instance.client.auth.currentUser?.id,
                  userType: widget.userType,
                  onTap: () => widget.onRequestSelectedForBid(request),
                  onDeleted: () => _removeRequest(request.id),
                );
              },
              childCount: visible.length,
            ),
          ),
        ),
        if (_loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

/// “Posted …” line using app strings + localized calendar date.
String _formatPostedLine(BuildContext context, DateTime createdAt) {
  final l10n = AppLocalizations.of(context)!;
  final local = createdAt.toLocal();
  final dateStr = MaterialLocalizations.of(context).formatShortDate(local);
  return l10n.postedOnDate(dateStr);
}

class _RequestCard extends StatefulWidget {
  const _RequestCard({
    required this.request,
    this.currentUserId,
    this.userType,
    this.onTap,
    this.onDeleted,
  });

  final TattooRequest request;
  final String? currentUserId;
  final String? userType;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  /// True when pointer is over the bid photo (where the bin sits).
  bool _hoveringBidImage = false;

  TattooRequest get request => widget.request;

  bool get _isOwner =>
      widget.currentUserId != null && request.userId == widget.currentUserId;

  /// Only customers can delete their own requests; tattoo artists cannot.
  bool get _canDelete => _isOwner && widget.userType != 'tattoo_artist';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: MouseRegion(
                onEnter: (_) {
                  if (_canDelete) {
                    setState(() => _hoveringBidImage = true);
                  }
                },
                onExit: (_) {
                  if (_canDelete) {
                    setState(() => _hoveringBidImage = false);
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      request.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image, size: 48)),
                    ),
                    if (request.status == 'completed')
                      Positioned(
                        top: 8,
                        left: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              l10n.bidClosed,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    if (_canDelete)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: _DeleteButton(
                          requestId: request.id,
                          onDeleted: widget.onDeleted,
                          highlightFromParent: _hoveringBidImage,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (request.customerName != null &&
                      request.customerName!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        request.customerName!,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (request.customerLocation != null &&
                      request.customerLocation!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              request.customerLocation!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatPostedLine(context, request.createdAt),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    l10n.requestBidsCount(request.bidCount),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: request.bidCount >= 1
                              ? Colors.green
                              : Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${request.startingBid.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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

class _DeleteButton extends StatefulWidget {
  const _DeleteButton({
    required this.requestId,
    this.onDeleted,
    this.highlightFromParent = false,
  });

  final String requestId;
  final VoidCallback? onDeleted; // Called after successful delete

  /// When the customer hovers the bid image, the bin still highlights (web/desktop).
  final bool highlightFromParent;

  @override
  State<_DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<_DeleteButton> {
  bool _deleting = false;
  bool _hoveringDelete = false;

  bool get _highlight => widget.highlightFromParent || _hoveringDelete;

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await TattooRequestService.deleteRequest(widget.requestId);
      if (!mounted) return;
      widget.onDeleted?.call();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.exploreDeleteFailedDetails(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Resting bin: light grey on dark chip; pointer on button → solid white ([InkWell.onHover]).
    final bg = _highlight ? Colors.black87 : Colors.black54;
    final iconColor = _hoveringDelete
        ? Colors.white
        : (_highlight ? scheme.error : Colors.white.withValues(alpha: 0.82));

    return Tooltip(
      message: 'Delete this post',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: _highlight
              ? [
                  BoxShadow(
                    color: scheme.error.withValues(alpha: 0.45),
                    blurRadius: 8,
                    spreadRadius: 0.5,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: _deleting ? null : _delete,
            customBorder: const CircleBorder(),
            // Prefer [onHover] over [MouseRegion] — more reliable on Flutter web.
            onHover: (hovered) {
              if (_hoveringDelete != hovered) {
                setState(() => _hoveringDelete = hovered);
              }
            },
            hoverColor: Colors.white.withValues(alpha: 0.15),
            splashColor: Colors.white.withValues(alpha: 0.25),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: _deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _highlight ? Icons.delete : Icons.delete_outline,
                      size: _highlight ? 22 : 20,
                      color: iconColor,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
