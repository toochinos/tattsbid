import 'package:flutter/material.dart';

import '../core/utils/user_type_utils.dart';

/// Red “⭐ PROMO” pill for artist portfolio posts on Explore (top-left of image).
class PromoBadgeOverlay extends StatelessWidget {
  const PromoBadgeOverlay({
    super.key,
    this.top = defaultTop,
    this.left = defaultLeft,
  });

  static const double defaultTop = 10;
  static const double defaultLeft = 10;

  static const Color badgeRed = Color(0xFFDC4A4A);

  final double top;
  final double left;

  /// True when the post owner is a tattoo artist (artist promo / portfolio post).
  static bool showForPosterType(String? posterUserType) =>
      canonicalUserType(posterUserType) == 'tattoo_artist';

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: badgeRed,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.star,
                  color: Colors.white,
                  size: 13,
                ),
                SizedBox(width: 4),
                Text(
                  'PROMO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.3,
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
