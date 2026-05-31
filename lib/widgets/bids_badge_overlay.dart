import 'package:flutter/material.dart';

import '../core/utils/user_type_utils.dart';

/// Blue “🔨 N BIDS” pill for customer job posts on Explore (top-left of image).
class BidsBadgeOverlay extends StatelessWidget {
  const BidsBadgeOverlay({
    super.key,
    required this.bidCount,
    this.top = defaultTop,
    this.left = defaultLeft,
  });

  static const double defaultTop = 10;
  static const double defaultLeft = 10;

  static const Color badgeBlue = Color(0xFF1D5DCE);

  final int bidCount;
  final double top;
  final double left;

  /// True when the post owner is a customer (customer job request / bid post).
  static bool showForPosterType(String? posterUserType) =>
      isCustomerBidPost(posterUserType);

  String get _label {
    final n = bidCount < 0 ? 0 : bidCount;
    return n == 1 ? '1 BID' : '$n BIDS';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: badgeBlue,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.gavel,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  _label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.2,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
