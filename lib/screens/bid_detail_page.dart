import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/bid.dart';
import '../core/models/tattoo_request.dart';
import 'platform_fee_page.dart';
import '../core/services/bid_service.dart';
import '../core/services/tattoo_request_service.dart';

/// Detail page for a tattoo request. Shows image and description.
/// Opened when artist or customer taps a request card in Explore.
/// Only tattoo artists can place bids; customers cannot.
class BidDetailPage extends StatefulWidget {
  const BidDetailPage({
    super.key,
    required this.request,
    this.userType,
  });

  final TattooRequest request;

  /// 'tattoo_artist' or 'customer'. Customers cannot place bids.
  final String? userType;

  @override
  State<BidDetailPage> createState() => _BidDetailPageState();
}

class _BidDetailPageState extends State<BidDetailPage> {
  bool _descriptionExpanded = false;
  List<Bid> _bids = [];
  bool _bidsLoading = true;
  String? _bidsError;
  String? _winningBidId;
  RealtimeChannel? _bidsChannel;
  Timer? _bidsPollTimer;

  @override
  void initState() {
    super.initState();
    _winningBidId = widget.request.winningBidId;
    _loadBids();
    _subscribeToBidsRealtime();
    _startBidsPollFallback();
  }

  bool get _isOwner {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null && user.id == widget.request.userId;
  }

  /// Only the customer who created the request can pick a winner and pay.
  /// (Requests are owned by customers; enforced by RLS on `tattoo_requests` too.)
  bool get _canSelectWinner => _isOwner;

  Future<void> _selectWinner(Bid bid) async {
    try {
      await TattooRequestService.setWinningBid(
        requestId: widget.request.id,
        bidId: bid.id,
      );
      if (!mounted) return;
      setState(() => _winningBidId = bid.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select winner: $e')),
      );
    }
  }

  Future<void> _payWinningBid(Bid bid) async {
    try {
      final platformFee = bid.amount * 0.08;
      final total = bid.amount;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlatformFeePage(
            requestId: widget.request.id,
            bidId: bid.id,
            bidAmount: bid.amount,
            platformFee: platformFee,
            total: total,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e')),
      );
    }
  }

  Future<void> makePayment(String bidId) async {
    Bid? bid;
    for (final b in _bids) {
      if (b.id == bidId) {
        bid = b;
        break;
      }
    }
    if (bid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find that bid to pay')),
      );
      return;
    }
    await _payWinningBid(bid);
  }

  Future<void> startPaymentFlow(Bid bid) async {
    final isWinner = _winningBidId == bid.id || bid.isWinner == true;
    if (!_canSelectWinner || !isWinner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Only the customer can pay the winning bid')),
      );
      return;
    }
    await _payWinningBid(bid);
  }

  @override
  void dispose() {
    _bidsChannel?.unsubscribe();
    _bidsPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBids({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _bidsLoading = true;
        _bidsError = null;
      });
    }
    try {
      final supabase = Supabase.instance.client;
      debugPrint('Request ID: ${widget.request.id}');
      final bidsResult = await supabase
          .from('bids')
          .select()
          .eq('request_id', widget.request.id);
      debugPrint('BIDS RESULT: $bidsResult');

      final allBids = await supabase.from('bids').select().limit(20);
      debugPrint('BIDS (first 20): $allBids');

      final bids = await BidService.fetchBidsForRequest(widget.request.id);
      if (!mounted) return;
      setState(() {
        if (_winningBidId == null) {
          final winner = bids.where((b) => b.isWinner == true).toList();
          if (winner.isNotEmpty) _winningBidId = winner.first.id;
        }
        _bids = bids;
        _bidsLoading = false;
        _bidsError = null;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _bidsLoading = false;
        _bidsError = e.toString();
      });
      debugPrint('Bid load error: $e\n$st');
    }
  }

  void _subscribeToBidsRealtime() {
    _bidsChannel = Supabase.instance.client
        .channel('bids_${widget.request.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bids',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'request_id',
            value: widget.request.id,
          ),
          callback: (_) => _loadBids(),
        )
        .subscribe();
  }

  void _startBidsPollFallback() {
    _bidsPollTimer?.cancel();
    _bidsPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      _loadBids();
    });
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPlaceBidDialog() async {
    final amount = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _PlaceBidDialog(),
    );

    if (amount != null && mounted) {
      try {
        await BidService.placeBid(
          requestId: widget.request.id,
          bidAmount: amount,
        );
        if (!mounted) return;
        await _loadBids(silent: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bid placed')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place bid: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final hasDescription = request.description?.trim().isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Request details'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                request.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, size: 64),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (request.customerName != null &&
                      request.customerName!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        request.customerName!,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                  Text(
                    '\$${request.startingBid.toStringAsFixed(2)} starting bid',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      setState(
                          () => _descriptionExpanded = !_descriptionExpanded);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _descriptionExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _descriptionExpanded
                                ? 'Hide description'
                                : 'What does the customer want?',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_descriptionExpanded) ...[
                    const SizedBox(height: 12),
                    if (hasDescription)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          request.description!,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    if (request.placement != null &&
                        request.placement!.trim().isNotEmpty)
                      _buildDetailRow(
                        context,
                        'Placement',
                        request.placement!,
                      ),
                    if (request.size != null && request.size!.trim().isNotEmpty)
                      _buildDetailRow(
                        context,
                        'Size',
                        request.size!,
                      ),
                    if (request.colourPreference != null &&
                        request.colourPreference!.trim().isNotEmpty)
                      _buildDetailRow(
                        context,
                        'Colour',
                        request.colourPreference == 'colour'
                            ? 'Colour'
                            : 'Black and grey',
                      ),
                    if (request.timeframe != null &&
                        request.timeframe!.trim().isNotEmpty)
                      _buildDetailRow(
                        context,
                        'Time frame',
                        request.timeframe == 'asap'
                            ? 'ASAP'
                            : (request.timeframe == 'during_the_week'
                                ? 'During the week'
                                : 'Whenever you can book me in'),
                      ),
                    if (request.artistCreativeFreedom)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.brush,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Artist has creative freedom',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    if (!hasDescription &&
                        (request.placement == null ||
                            request.placement!.trim().isEmpty) &&
                        (request.size == null ||
                            request.size!.trim().isEmpty) &&
                        (request.colourPreference == null ||
                            request.colourPreference!.trim().isEmpty) &&
                        (request.timeframe == null ||
                            request.timeframe!.trim().isEmpty) &&
                        !request.artistCreativeFreedom)
                      Text(
                        'No description provided.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        'Bids (tattoo artists only)',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      if (widget.userType == 'tattoo_artist') ...[
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _showPlaceBidDialog,
                          icon: const Icon(Icons.gavel, size: 18),
                          label: const Text('Bid'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_bidsLoading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_bidsError != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Could not load bids',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _bidsError!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _loadBids(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else if (_bids.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No bids yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _bids.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final bid = _bids[index];
                        final isWinner =
                            _winningBidId == bid.id || bid.isWinner == true;
                        return ListTile(
                          onTap: _canSelectWinner && isWinner
                              ? () => _payWinningBid(bid)
                              : null,
                          leading: CircleAvatar(
                            child: Text(
                              (bid.bidderName ?? '?')
                                  .substring(0, 1)
                                  .toUpperCase(),
                            ),
                          ),
                          title: Text(
                            bid.bidderName ?? 'Artist',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: isWinner
                              ? Text(
                                  _canSelectWinner
                                      ? 'Winner • Tap to pay'
                                      : 'Winner',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${bid.amount.toStringAsFixed(2)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              if (_canSelectWinner && !isWinner) ...[
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => _selectWinner(bid),
                                  child: const Text('Select'),
                                ),
                              ],
                              if (_canSelectWinner && isWinner) ...[
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: () => _payWinningBid(bid),
                                  child: const Text('Pay'),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
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

/// Dialog for placing a bid. Owns the controller and disposes it properly.
class _PlaceBidDialog extends StatefulWidget {
  const _PlaceBidDialog();

  @override
  State<_PlaceBidDialog> createState() => _PlaceBidDialogState();
}

class _PlaceBidDialogState extends State<_PlaceBidDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Place bid'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Your price (\$)',
            hintText: '0.00',
            prefixText: '\$ ',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          autofocus: true,
          validator: (v) {
            final n = double.tryParse(v?.trim() ?? '');
            if (n == null || n < 0) {
              return 'Enter a valid amount (0 or more)';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final n = double.tryParse(_controller.text.trim()) ?? 0;
            Navigator.of(context).pop(n);
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
