import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_schema.dart';
import '../core/constants/app_constants.dart';
import '../core/models/bid.dart';
import '../core/models/tattoo_request.dart';
import '../core/models/user_profile.dart';
import 'chat_page.dart';
import '../core/payment/pending_deposit_payment.dart';
import '../core/services/bid_service.dart';
import '../core/services/payment_service.dart';
import '../core/services/payment_status_service.dart';
import '../core/services/contact_unlock_service.dart';
import '../core/services/profile_service.dart';
import '../core/services/tattoo_request_service.dart';
import 'public_artist_profile_page.dart';
import '../l10n/app_localizations.dart';

/// Detail page for a tattoo request. Shows image and description.
/// Opened when artist or customer taps a request card in Explore.
/// Primary action uses [SupabaseProfiles.role] when set; otherwise legacy
/// [BidService.isCurrentUserTattooArtist] for the Bid button.
class BidDetailPage extends StatefulWidget {
  const BidDetailPage({
    super.key,
    required this.request,
  });

  final TattooRequest request;

  @override
  State<BidDetailPage> createState() => _BidDetailPageState();
}

class _BidDetailPageState extends State<BidDetailPage>
    with WidgetsBindingObserver {
  late TattooRequest _request;

  bool _descriptionExpanded = false;
  List<Bid> _bids = [];
  bool _bidsLoading = true;
  String? _bidsError;
  String? _winningBidId;
  RealtimeChannel? _bidsChannel;
  Timer? _bidsPollTimer;

  /// `profiles.role`: `artist` | `customer` (lowercase), or null if unset.
  String? _userRole;

  /// True until [profiles.role] (and legacy bid eligibility if needed) is loaded.
  bool _profileRoleLoading = true;

  /// When [_userRole] is null, use same check as [BidService.placeBid] for Bid UI.
  bool _legacyTattooArtist = false;

  /// [profiles.user_type] for the signed-in user (for customer-only contact unlock UI).
  String? _viewerUserType;

  /// [profiles.country] for country match when placing bids as a tattoo artist.
  String? _viewerProfileCountry;

  /// From [ContactUnlockService.checkIfUnlocked] — paid contact unlock for this request.
  bool _hasUnlocked = false;

  bool _unlockLoading = false;
  UserProfile? _winnerArtistProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _request = widget.request;
    _winningBidId = _request.winningBidId;
    _loadBids();
    _subscribeToBidsRealtime();
    _startBidsPollFallback();
    _loadProfileRole();
    _loadUnlock();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshRequestAndUnlock();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshRequestAndUnlock();
    }
  }

  /// After Stripe, [contact_unlocks] and request status update server-side — refetch.
  Future<void> _refreshRequestAndUnlock() async {
    final fresh = await TattooRequestService.fetchRequestById(_request.id);
    if (!mounted) return;
    if (fresh != null) {
      setState(() {
        _request = fresh;
        if (fresh.winningBidId != null) {
          _winningBidId = fresh.winningBidId;
        }
      });
      await _loadBids(silent: true);
    } else {
      await _loadUnlock();
    }
  }

  /// Reads [SupabaseProfiles.role] for the signed-in user; on error or missing
  /// column, falls back to legacy tattoo-artist detection only.
  Future<void> _loadProfileRole() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _profileRoleLoading = false;
        _userRole = null;
        _legacyTattooArtist = false;
        _viewerUserType = null;
        _viewerProfileCountry = null;
      });
      return;
    }

    try {
      final row = await client
          .from(SupabaseProfiles.table)
          .select(
            '${SupabaseProfiles.role}, ${SupabaseProfiles.userType}, ${SupabaseProfiles.country}',
          )
          .eq(SupabaseProfiles.id, user.id)
          .maybeSingle();

      String? normalizedRole;
      final raw = row?[SupabaseProfiles.role] as String?;
      if (raw != null && raw.trim().isNotEmpty) {
        normalizedRole = raw.trim().toLowerCase();
      }

      final legacy = normalizedRole == null
          ? await BidService.isCurrentUserTattooArtist()
          : false;

      final ut = row?[SupabaseProfiles.userType] as String?;
      final viewerUt = ut?.trim();
      final rawCountry = row?[SupabaseProfiles.country] as String?;
      final trimmedCountry = rawCountry?.trim();
      final viewerCountry = trimmedCountry != null && trimmedCountry.isNotEmpty
          ? trimmedCountry
          : null;

      if (!mounted) return;
      setState(() {
        _profileRoleLoading = false;
        _userRole = normalizedRole;
        _legacyTattooArtist = legacy;
        _viewerUserType = viewerUt?.isEmpty == true ? null : viewerUt;
        _viewerProfileCountry = viewerCountry;
      });
      await _loadUnlock();
    } catch (e, st) {
      debugPrint('BidDetailPage _loadProfileRole: $e\n$st');
      final legacy = await BidService.isCurrentUserTattooArtist();
      if (!mounted) return;
      setState(() {
        _profileRoleLoading = false;
        _userRole = null;
        _legacyTattooArtist = legacy;
        _viewerUserType = null;
        _viewerProfileCountry = null;
      });
      await _loadUnlock();
    }
  }

  /// Request owner who is not a tattoo artist (customers only for unlock UI).
  bool get _showArtistContactSection =>
      _isOwner &&
      !_profileRoleLoading &&
      (_viewerUserType == null || _viewerUserType != 'tattoo_artist') &&
      _winningBidId != null;

  Bid? get _winningBidModel {
    final id = _winningBidId;
    if (id == null) return null;
    for (final b in _bids) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Agreed job price (winning bid amount) — basis for 10% deposit.
  double? get _jobPrice => _winningBidModel?.amount;

  double? get _depositDollars =>
      _jobPrice != null ? _jobPrice! * AppConstants.platformFeeRate : null;

  double? get _remainingDollars => _jobPrice != null
      ? _jobPrice! * (1.0 - AppConstants.platformFeeRate)
      : null;

  /// Loads [contact_unlocks] via [ContactUnlockService.checkIfUnlocked], then artist profile for display.
  Future<void> _loadUnlock() async {
    if (_profileRoleLoading) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _unlockLoading = false;
        _hasUnlocked = false;
        _winnerArtistProfile = null;
      });
      return;
    }

    if (!_isOwner || _winningBidId == null) {
      if (!mounted) return;
      setState(() {
        _unlockLoading = false;
        _hasUnlocked = false;
        _winnerArtistProfile = null;
      });
      return;
    }
    if (_viewerUserType == 'tattoo_artist') {
      if (!mounted) return;
      setState(() {
        _unlockLoading = false;
        _hasUnlocked = false;
        _winnerArtistProfile = null;
      });
      return;
    }

    if (!_showArtistContactSection) {
      if (!mounted) return;
      setState(() {
        _unlockLoading = false;
        _hasUnlocked = false;
        _winnerArtistProfile = null;
      });
      return;
    }
    final bid = _winningBidModel;
    final artistId = bid?.bidderId ?? bid?.artistId;
    if (artistId == null || artistId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _unlockLoading = false;
        _hasUnlocked = false;
        _winnerArtistProfile = null;
      });
      return;
    }

    setState(() => _unlockLoading = true);
    try {
      final rowUnlocked = await ContactUnlockService.checkIfUnlocked(
        userId: user.id,
        artistId: artistId,
        requestId: _request.id,
      );
      final bidPaid = (_winningBidModel?.paymentStatus ?? '') == 'paid';
      final showContactAndChat = rowUnlocked || bidPaid;
      UserProfile? prof;
      if (showContactAndChat) {
        prof = await ProfileService.getProfileByUserId(artistId);
      }
      if (!mounted) return;
      setState(() {
        _unlockLoading = false;
        _hasUnlocked = showContactAndChat;
        _winnerArtistProfile = prof;
      });
    } catch (e, st) {
      debugPrint('BidDetailPage _loadUnlock: $e\n$st');
      if (!mounted) return;
      setState(() {
        _unlockLoading = false;
        _hasUnlocked = false;
        _winnerArtistProfile = null;
      });
    }
  }

  /// Bidding only while the request is [open]. Closed after winner / payment.
  bool get _biddingOpen => _request.status == 'open';

  /// Same visibility rules as the Bid button before country gating.
  bool get _bidButtonBaseEligible =>
      !_profileRoleLoading &&
      _biddingOpen &&
      !_isOwner &&
      (_userRole == 'customer' || (_userRole == null && _legacyTattooArtist));

  bool get _isTattooArtistViewer =>
      _viewerUserType == 'tattoo_artist' || _legacyTattooArtist;

  /// Tattoo artists may only bid when [TattooRequest.country] matches profile country.
  bool get _countriesAllowArtistBid {
    if (!_isTattooArtistViewer) return true;
    final req = _request.country?.trim();
    final prof = _viewerProfileCountry?.trim();
    if (req == null || req.isEmpty) return false;
    if (prof == null || prof.isEmpty) return false;
    return req.toLowerCase() == prof.toLowerCase();
  }

  /// Role `customer` from [profiles.role], or legacy tattoo artist when role unset.
  bool get _showBidButton => _bidButtonBaseEligible && _countriesAllowArtistBid;

  bool get _showBidCountryBlockedHint =>
      _bidButtonBaseEligible &&
      _isTattooArtistViewer &&
      !_countriesAllowArtistBid;

  /// Role `artist`: show tools entry — does not open the bid dialog.
  bool get _showArtistToolsButton =>
      !_profileRoleLoading &&
      _userRole == 'artist' &&
      _biddingOpen &&
      !_isOwner;

  /// Matches [_showBidButton] — used before submitting a bid.
  bool get _canSubmitBid => _showBidButton;

  bool get _isOwner {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null && user.id == _request.userId;
  }

  /// Only the customer who created the request can select a bid and pay.
  /// (Requests are owned by customers; enforced by RLS on `tattoo_requests` too.)
  bool get _canSelectWinner => _isOwner;

  /// Deposit already paid — no further Pay actions (see [markRequestCompletedAfterPayment]).
  bool get _depositPaid => _request.status == 'completed';

  /// STEP 5: show contact when winning bid is paid in DB or [contact_unlocks] row exists.
  bool get _paidForContact =>
      (_winningBidModel?.paymentStatus ?? '') == 'paid' || _hasUnlocked;

  /// Customer may pay the winning bid only until the request is completed.
  bool get _canPayWinningBid => _canSelectWinner && !_depositPaid;

  /// Bid whose amount is closest to the customer's [TattooRequest.startingBid].
  /// Ties: lower bid amount wins.
  static String? _bidIdClosestToStartingPrice(
    List<Bid> bids,
    double startingBid,
  ) {
    if (bids.isEmpty) return null;
    Bid? best;
    var bestDiff = double.infinity;
    for (final b in bids) {
      final diff = (b.amount - startingBid).abs();
      if (best == null) {
        best = b;
        bestDiff = diff;
      } else if (diff < bestDiff) {
        best = b;
        bestDiff = diff;
      } else if (diff == bestDiff && b.amount < best.amount) {
        best = b;
      }
    }
    return best?.id;
  }

  void _openBidderProfile(Bid bid) {
    final uid = bid.bidderId ?? bid.artistId;
    if (uid == null || uid.trim().isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.bidDetailCouldNotOpenProfile)),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PublicArtistProfilePage(
          userId: uid,
          fromArtistsDirectory: false,
        ),
      ),
    );
  }

  Future<void> _selectWinner(Bid bid) async {
    if (_depositPaid) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.bidDetailRequestAlreadyCompleted),
        ),
      );
      return;
    }
    try {
      await TattooRequestService.setWinningBid(
        requestId: _request.id,
        bidId: bid.id,
      );
      if (!mounted) return;
      setState(() => _winningBidId = bid.id);

      final artistId = bid.bidderId ?? bid.artistId;
      if (!AppConstants.isDepositPaymentEnabled &&
          artistId != null &&
          artistId.isNotEmpty) {
        try {
          await ContactUnlockService.recordUnlockAfterSuccessfulPayment(
            requestId: _request.id,
            artistId: artistId,
            depositAmount: 0,
          );
        } catch (e, st) {
          debugPrint('BidDetailPage free unlock: $e\n$st');
          if (!mounted) return;
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.bidDetailCouldNotUnlockContactDetails('$e')),
            ),
          );
        }
      }

      // Stay on request details; [_loadUnlock] shows artist phone, email, and Chat.
      await _loadBids(silent: true);
      await _loadUnlock();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.bidDetailCouldNotSelectBidDetails('$e'))),
      );
    }
  }

  Future<void> _payWinningBid(Bid bid) async {
    if (!AppConstants.isDepositPaymentEnabled) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.bidDetailTapChooseArtistHint),
        ),
      );
      return;
    }
    if (_depositPaid) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.bidDetailPaymentAlreadyCompleted),
        ),
      );
      return;
    }
    final artistId = bid.bidderId ?? bid.artistId;
    if (artistId == null || artistId.isEmpty) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.bidDetailMissingArtistForBid)),
      );
      return;
    }
    try {
      final platformFee = bid.amount * AppConstants.platformFeeRate;
      PendingDepositPayment.requestId = _request.id;
      PendingDepositPayment.artistUserId = artistId;
      PendingDepositPayment.depositAmount = platformFee;
      final uid = Supabase.instance.client.auth.currentUser?.id;
      await startPayment(
        amount: platformFee,
        bidId: bid.id,
        receiverId: artistId,
        requestId: _request.id,
        userId: uid,
        depositAmount: platformFee,
      );
      // startPayment returns when Stripe opens, not when payment completes.
      if (!mounted) return;
      await PaymentStatusService.checkPaymentStatusAfterCheckoutLaunched(
        context,
        _request.id,
      );
      if (mounted) await _loadUnlock();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.bidDetailPaymentFailedDetails('$e'))),
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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.bidDetailCouldNotFindBidToPay)),
      );
      return;
    }
    await _payWinningBid(bid);
  }

  Future<void> startPaymentFlow(Bid bid) async {
    final isWinner = _winningBidId == bid.id || bid.isWinner == true;
    if (!_canSelectWinner || !isWinner) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.bidDetailOnlyCustomerCanPay),
        ),
      );
      return;
    }
    await _payWinningBid(bid);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      debugPrint('Request ID: ${_request.id}');
      final bidsResult =
          await supabase.from('bids').select().eq('request_id', _request.id);
      debugPrint('BIDS RESULT: $bidsResult');

      final allBids = await supabase.from('bids').select().limit(20);
      debugPrint('BIDS (first 20): $allBids');

      final bids = await BidService.fetchBidsForRequest(_request.id);
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
      await _loadUnlock();
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
        .channel('bids_${_request.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bids',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'request_id',
            value: _request.id,
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

  void _onArtistToolsPressed() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.bidDetailArtistToolsSheetTitle,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.bidDetailArtistToolsSheetBody,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(ctx).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPlaceBidDialog() async {
    if (!_canSubmitBid) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.bidDetailCannotPlaceBid),
        ),
      );
      return;
    }
    if (!_biddingOpen) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.bidDetailBiddingClosedSnackbar),
        ),
      );
      return;
    }
    final amount = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const _PlaceBidDialog(),
    );

    if (amount != null && mounted) {
      try {
        await BidService.placeBid(
          requestId: _request.id,
          bidAmount: amount,
        );
        if (!mounted) return;
        await _loadBids(silent: true);
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.bidDetailBidPlaced)),
        );
      } on BidCountryBlockedException catch (e) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        final message = switch (e.kind) {
          BidCountryBlockedKind.requestCountryMissing =>
            l10n.bidDetailBidCountryRequestMissingHint,
          BidCountryBlockedKind.profileCountryMissing =>
            l10n.bidDetailBidCountryProfileMissingHint,
          BidCountryBlockedKind.mismatch =>
            l10n.bidDetailBidCountryMismatchHint(
              e.requestCountry ?? '',
              e.profileCountry ?? '',
            ),
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.bidDetailFailedPlaceBidDetails('$e')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final request = _request;
    final hasDescription = request.description?.trim().isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.bidDetailTitle),
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
                    l10n.bidDetailStartingBid(
                      '\$${request.startingBid.toStringAsFixed(2)}',
                    ),
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
                                ? l10n.bidDetailHideDescription
                                : l10n.bidDetailWhatCustomerWants,
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
                        l10n.bidDetailPlacement,
                        request.placement!,
                      ),
                    if (request.size != null && request.size!.trim().isNotEmpty)
                      _buildDetailRow(
                        context,
                        l10n.bidDetailSize,
                        request.size!,
                      ),
                    if (request.colourPreference != null &&
                        request.colourPreference!.trim().isNotEmpty)
                      _buildDetailRow(
                        context,
                        l10n.bidDetailColour,
                        request.colourPreference == 'colour'
                            ? l10n.bidDetailColourFull
                            : l10n.bidDetailColourBlackGrey,
                      ),
                    if (request.timeframe != null &&
                        request.timeframe!.trim().isNotEmpty)
                      _buildDetailRow(
                        context,
                        l10n.bidDetailTimeFrame,
                        request.timeframe == 'asap'
                            ? l10n.bidDetailTimeframeAsap
                            : (request.timeframe == 'during_the_week'
                                ? l10n.bidDetailTimeframeWeek
                                : l10n.bidDetailTimeframeFlexible),
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
                              l10n.bidDetailArtistCreativeFreedom,
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
                        l10n.bidDetailNoDescription,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.bidDetailBids,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            if (!_profileRoleLoading &&
                                _userRole == 'artist' &&
                                _biddingOpen &&
                                !_isOwner) ...[
                              const SizedBox(height: 6),
                              Text(
                                l10n.bidDetailArtistToolsNotBidHint,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ],
                            if (!_profileRoleLoading &&
                                _userRole == null &&
                                !_legacyTattooArtist &&
                                !_isOwner) ...[
                              const SizedBox(height: 6),
                              Text(
                                l10n.bidDetailOnlyArtistsMayBid,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ],
                            if (_showBidCountryBlockedHint) ...[
                              const SizedBox(height: 6),
                              Text(
                                _request.country?.trim().isEmpty ?? true
                                    ? l10n.bidDetailBidCountryRequestMissingHint
                                    : (_viewerProfileCountry?.trim().isEmpty ??
                                            true)
                                        ? l10n
                                            .bidDetailBidCountryProfileMissingHint
                                        : l10n.bidDetailBidCountryMismatchHint(
                                            _request.country!.trim(),
                                            _viewerProfileCountry!.trim(),
                                          ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ],
                            if (!_profileRoleLoading &&
                                !_isOwner &&
                                !_biddingOpen &&
                                (_userRole == 'artist' ||
                                    _userRole == 'customer' ||
                                    (_userRole == null &&
                                        _legacyTattooArtist))) ...[
                              const SizedBox(height: 6),
                              Text(
                                l10n.bidDetailBiddingClosedMessage,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_profileRoleLoading) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                      if (_showArtistToolsButton) ...[
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: _onArtistToolsPressed,
                          icon: const Icon(Icons.palette_outlined, size: 18),
                          label: Text(l10n.bidDetailViewArtistTools),
                        ),
                      ],
                      if (_showBidButton) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _showPlaceBidDialog,
                          icon: const Icon(Icons.gavel, size: 18),
                          label: Text(l10n.bidDetailBid),
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
                            l10n.bidDetailCouldNotLoadBids,
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
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    )
                  else if (_bids.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.bidDetailNoBidsYet,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    )
                  else
                    Builder(
                      builder: (context) {
                        final closestId = _bidIdClosestToStartingPrice(
                          _bids,
                          request.startingBid,
                        );
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _bids.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final bid = _bids[index];
                            final isSelectedForPayment =
                                _winningBidId == bid.id || bid.isWinner == true;
                            final isClosestToCustomerPrice =
                                closestId != null && bid.id == closestId;
                            final subtitleParts = <String>[];
                            if (isClosestToCustomerPrice) {
                              subtitleParts.add(l10n.bidDetailLowest);
                            }
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _showArtistContactSection
                                    ? null
                                    : (AppConstants.isDepositPaymentEnabled &&
                                            _canPayWinningBid &&
                                            isSelectedForPayment
                                        ? () => _payWinningBid(bid)
                                        : null),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 4,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        child: Text(
                                          (bid.bidderName ?? '?')
                                              .substring(0, 1)
                                              .toUpperCase(),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            InkWell(
                                              onTap: () =>
                                                  _openBidderProfile(bid),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 2,
                                                ),
                                                child: Text(
                                                  bid.bidderName ??
                                                      l10n.bidDetailArtistNameFallback,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            if (subtitleParts.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                subtitleParts.join(' • '),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
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
                                          if (_canPayWinningBid &&
                                              !isSelectedForPayment)
                                            FilledButton.tonalIcon(
                                              onPressed: () =>
                                                  _selectWinner(bid),
                                              icon: const Icon(
                                                Icons.person_add_alt_1,
                                                size: 18,
                                              ),
                                              label: Text(
                                                  l10n.bidDetailChooseArtist),
                                              style: FilledButton.styleFrom(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                              ),
                                            ),
                                          if (_canSelectWinner &&
                                              isSelectedForPayment) ...[
                                            if (_depositPaid || _paidForContact)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Text(
                                                  l10n.bidDetailPaid,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelLarge
                                                      ?.copyWith(
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              )
                                            else if (!_showArtistContactSection &&
                                                AppConstants
                                                    .isDepositPaymentEnabled)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: FilledButton(
                                                  onPressed: () =>
                                                      _payWinningBid(bid),
                                                  child: Text(
                                                    l10n.bidDetailUnlockContact,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  if (_showArtistContactSection) ...[
                    const SizedBox(height: 20),
                    Text(
                      (!_unlockLoading && _paidForContact)
                          ? l10n.bidDetailSectionArtistContact
                          : AppConstants.isDepositPaymentEnabled
                              ? l10n.bidDetailSectionDeposit
                              : l10n.bidDetailSectionConnect,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _buildArtistContactSection(context, l10n),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChatWithArtist(String artistUserId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(initialReceiverId: artistUserId),
      ),
    );
  }

  /// Loading / unlocked contact / 10% deposit lines + pay button — all inline on this page (no new screen).
  Widget _buildArtistContactSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final scheme = Theme.of(context).colorScheme;

    if (_unlockLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_depositPaid && !_paidForContact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.bidDetailPaymentCompleteBody,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await _refreshRequestAndUnlock();
            },
            icon: const Icon(Icons.refresh),
            label: Text(l10n.bidDetailRefreshUnlockStatus),
          ),
        ],
      );
    }

    // STEP 5: contact only if paid (DB payment_status or contact_unlocks).
    if (_paidForContact) {
      final p = _winnerArtistProfile;
      final artistPhone = (p?.mobile != null && p!.mobile!.trim().isNotEmpty)
          ? p.mobile!.trim()
          : '—';
      final artistEmail =
          (p?.contactEmail != null && p!.contactEmail!.trim().isNotEmpty)
              ? p.contactEmail!.trim()
              : '—';
      final artistChatId =
          _winningBidModel?.bidderId ?? _winningBidModel?.artistId;

      return _ContactDetailsWidget(
        phone: artistPhone,
        email: artistEmail,
        onChat: artistChatId != null && artistChatId.isNotEmpty
            ? () => _openChatWithArtist(artistChatId)
            : null,
      );
    }

    final price = _jobPrice;
    final dep = _depositDollars;
    final rem = _remainingDollars;
    if (price == null || dep == null || rem == null) {
      return Text(
        AppConstants.isDepositPaymentEnabled
            ? l10n.bidDetailChooseWinningBidForDeposit
            : l10n.bidDetailChooseWinningBidToConnect,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.outline,
            ),
      );
    }

    final payBlocked = _winningBidModel == null;

    if (!AppConstants.isDepositPaymentEnabled) {
      return Text(
        l10n.bidDetailChooseWinningBidToChat,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.outline,
            ),
      );
    }

    return _DepositPayButton(
      totalPrice: price,
      deposit: dep,
      remaining: rem,
      remainingPercent: 100 - AppConstants.platformFeePercent,
      onPay: payBlocked ? null : () => _payWinningBid(_winningBidModel!),
    );
  }
}

/// Shown when [Bid.paymentStatus] is `paid` or [contact_unlocks] exists.
class _ContactDetailsWidget extends StatelessWidget {
  const _ContactDetailsWidget({
    required this.phone,
    required this.email,
    this.onChat,
  });

  final String phone;
  final String email;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.bidDetailPhoneLine(phone),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.bidDetailEmailLine(email),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (onChat != null) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onChat,
            child: Text(l10n.bidDetailChat),
          ),
        ],
      ],
    );
  }
}

/// Deposit breakdown + pay when not yet [Bid.paymentStatus] == paid.
class _DepositPayButton extends StatelessWidget {
  const _DepositPayButton({
    required this.totalPrice,
    required this.deposit,
    required this.remaining,
    required this.remainingPercent,
    this.onPay,
  });

  final double totalPrice;
  final double deposit;
  final double remaining;
  final int remainingPercent;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final totalStr = '\$${totalPrice.toStringAsFixed(2)}';
    final depStr = '\$${deposit.toStringAsFixed(2)}';
    final remStr = '\$${remaining.toStringAsFixed(2)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.bidDetailTotalPriceLine(totalStr),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.bidDetailDepositLine(
            AppConstants.platformFeePercent,
            depStr,
          ),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.bidDetailRemainingLine(remainingPercent, remStr),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.outline,
              ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onPay,
          child: Text(
            l10n.bidDetailPayDepositUnlock(AppConstants.platformFeePercent),
          ),
        ),
      ],
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
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.bidDetailPlaceBidTitle),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: l10n.bidDetailYourPriceLabel,
            hintText: '0.00',
            prefixText: '\$ ',
            border: const OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          autofocus: true,
          validator: (v) {
            final n = double.tryParse(v?.trim() ?? '');
            if (n == null || n < 0) {
              return l10n.bidDetailEnterValidBidAmount;
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.bidDetailCancel),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final n = double.tryParse(_controller.text.trim()) ?? 0;
            Navigator.of(context).pop(n);
          },
          child: Text(l10n.bidDetailSubmit),
        ),
      ],
    );
  }
}
