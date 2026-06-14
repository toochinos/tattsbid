import 'package:flutter_test/flutter_test.dart';
import 'package:saas_app/core/utils/bid_card_action_rules.dart';

void main() {
  group('BidCardActionRules', () {
    test('own post — no buttons', () {
      const rules = BidCardActionRules(
        isPromoPost: false,
        isOwner: true,
        biddingOpen: true,
        profileRoleLoading: false,
        isViewerArtist: true,
      );
      expect(rules.showChat, isFalse);
      expect(rules.showBidButton, isFalse);
      expect(rules.canSubmitBid, isFalse);
    });

    test('closed customer job — artist still sees Chat + Bid', () {
      const rules = BidCardActionRules(
        isPromoPost: false,
        isOwner: false,
        biddingOpen: false,
        profileRoleLoading: false,
        isViewerArtist: true,
      );
      expect(rules.showChat, isTrue);
      expect(rules.showBidButton, isTrue);
      expect(rules.canSubmitBid, isFalse);
    });

    test('closed customer job — customer sees no buttons', () {
      const rules = BidCardActionRules(
        isPromoPost: false,
        isOwner: false,
        biddingOpen: false,
        profileRoleLoading: false,
        isViewerArtist: false,
      );
      expect(rules.showChat, isFalse);
      expect(rules.showBidButton, isFalse);
    });

    test('closed promo — no buttons', () {
      const rules = BidCardActionRules(
        isPromoPost: true,
        isOwner: false,
        biddingOpen: false,
        profileRoleLoading: false,
        isViewerArtist: true,
      );
      expect(rules.showChat, isFalse);
      expect(rules.showBidButton, isFalse);
    });

    test('customer job — artist sees Chat + Bid, can submit', () {
      const rules = BidCardActionRules(
        isPromoPost: false,
        isOwner: false,
        biddingOpen: true,
        profileRoleLoading: false,
        isViewerArtist: true,
      );
      expect(rules.showChat, isTrue);
      expect(rules.showBidButton, isTrue);
      expect(rules.canSubmitBid, isTrue);
    });

    test('customer job — customer sees Chat only, no Bid', () {
      const rules = BidCardActionRules(
        isPromoPost: false,
        isOwner: false,
        biddingOpen: true,
        profileRoleLoading: false,
        isViewerArtist: false,
      );
      expect(rules.showChat, isTrue);
      expect(rules.showBidButton, isFalse);
      expect(rules.canSubmitBid, isFalse);
    });

    test('promo — customer sees Chat + Bid, can submit', () {
      const rules = BidCardActionRules(
        isPromoPost: true,
        isOwner: false,
        biddingOpen: true,
        profileRoleLoading: false,
        isViewerArtist: false,
      );
      expect(rules.showChat, isTrue);
      expect(rules.showBidButton, isTrue);
      expect(rules.canSubmitBid, isTrue);
    });

    test('promo — artist sees Chat only', () {
      const rules = BidCardActionRules(
        isPromoPost: true,
        isOwner: false,
        biddingOpen: true,
        profileRoleLoading: false,
        isViewerArtist: true,
      );
      expect(rules.showChat, isTrue);
      expect(rules.showBidButton, isFalse);
      expect(rules.canSubmitBid, isFalse);
    });

    test('resolveViewerIsArtist — tattoo_artist user_type', () {
      expect(
        BidCardActionRules.resolveViewerIsArtist(
          profileRole: 'customer',
          profileUserType: 'tattoo_artist',
        ),
        isTrue,
      );
    });

    test('resolveViewerIsArtist — customer user_type', () {
      expect(
        BidCardActionRules.resolveViewerIsArtist(
          profileRole: null,
          profileUserType: 'customer',
        ),
        isFalse,
      );
    });
  });
}
