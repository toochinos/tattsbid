import 'user_type_utils.dart';

/// Chat / Bid button visibility and submit eligibility for Explore cards and
/// [BidDetailPage].
///
/// Locked-in product rules:
/// - **Customer job detail (artist viewer)** — Chat + Bid always shown; submit only when open.
/// - **Customer job detail (customer viewer)** — Chat when open; no Bid button.
/// - **Promo cards** — Chat for non-owners; only customers submit bids.
/// - **Own posts** — no buttons. **Closed promos / closed jobs (non-artist)** — no buttons.
class BidCardActionRules {
  const BidCardActionRules({
    required this.isPromoPost,
    required this.isOwner,
    required this.biddingOpen,
    required this.profileRoleLoading,
    required this.isViewerArtist,
  });

  final bool isPromoPost;
  final bool isOwner;
  final bool biddingOpen;
  final bool profileRoleLoading;
  final bool isViewerArtist;

  factory BidCardActionRules.from({
    required String? posterUserType,
    required bool isOwner,
    required String requestStatus,
    required bool profileRoleLoading,
    required bool isViewerArtist,
  }) {
    return BidCardActionRules(
      isPromoPost: canonicalUserType(posterUserType) == 'tattoo_artist',
      isOwner: isOwner,
      biddingOpen: requestStatus == 'open',
      profileRoleLoading: profileRoleLoading,
      isViewerArtist: isViewerArtist,
    );
  }

  bool get _canViewActions => !profileRoleLoading && !isOwner;

  /// Open requests — required to submit a bid, not always for button visibility.
  bool get _interactive => _canViewActions && biddingOpen;

  /// Chat: artists always on customer jobs; others when bidding is open.
  bool get showChat {
    if (!_canViewActions) return false;
    if (!isPromoPost && isViewerArtist) return true;
    return biddingOpen;
  }

  /// Bid button on the detail page UI.
  bool get showBidButton {
    if (!_canViewActions) return false;
    if (isPromoPost) return biddingOpen && !isViewerArtist;
    return isViewerArtist;
  }

  /// Who may open the place-bid dialog / call [BidService.placeBid].
  bool get canSubmitBid {
    if (!_interactive) return false;
    if (isPromoPost) return !isViewerArtist;
    return isViewerArtist;
  }

  bool get showAnyAction => showChat || showBidButton;

  /// Whether the signed-in user is a tattoo artist (must not bid on promos).
  ///
  /// Uses [profileUserType] first (matches [BidService.placeBid]), then
  /// [profileRole], then [legacyTattooArtist].
  static bool resolveViewerIsArtist({
    String? profileRole,
    String? profileUserType,
    bool legacyTattooArtist = false,
  }) {
    if (canonicalUserType(profileUserType) == 'tattoo_artist') return true;
    final role = profileRole?.trim().toLowerCase();
    if (role == 'artist') return true;
    return legacyTattooArtist;
  }
}
