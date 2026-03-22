import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/tattoo_request.dart';
import '../core/services/tattoo_request_service.dart';

/// Explore tab - displays open tattoo requests (photos from customers).
class ExplorePage extends StatefulWidget {
  const ExplorePage({
    super.key,
    this.refreshTrigger,
    this.userType,
    required this.onRequestSelectedForBid,
  });

  /// When this value changes, the page refetches tattoo requests.
  final ValueListenable<int>? refreshTrigger;

  /// 'tattoo_artist' or 'customer'. Tattoo artists cannot delete explore photos.
  final String? userType;

  /// When tapping a request, switches to Bid tab and shows detail.
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

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _subscribeToRealtime();
    _startPollingFallback();
    widget.refreshTrigger?.addListener(_onRefreshTriggered);
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
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    widget.refreshTrigger?.removeListener(_onRefreshTriggered);
    super.dispose();
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
      final requests = await TattooRequestService.fetchOpenRequests();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: RefreshIndicator(onRefresh: _loadRequests, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _requests.isEmpty) {
      return Center(
        child: Padding(
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
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_requests.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tattoo requests yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a request to see it here',
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
            delegate: SliverChildBuilderDelegate((context, index) {
              final request = _requests[index];
              return _RequestCard(
                request: request,
                currentUserId: Supabase.instance.client.auth.currentUser?.id,
                userType: widget.userType,
                onTap: () => widget.onRequestSelectedForBid(request),
                onDeleted: () => _removeRequest(request.id),
              );
            }, childCount: _requests.length),
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

/// Localized short date for when the customer posted the request.
String _formatPostedDate(BuildContext context, DateTime createdAt) {
  final local = createdAt.toLocal();
  return MaterialLocalizations.of(context).formatShortDate(local);
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
    return Card(
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
                              'Bid closed',
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
                          'Posted ${_formatPostedDate(context, request.createdAt)}',
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
                    '${request.bidCount} bid${request.bidCount == 1 ? '' : 's'}',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: ${e.toString()}'),
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
        : (_highlight
            ? scheme.error
            : Colors.white.withValues(alpha: 0.82));

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
