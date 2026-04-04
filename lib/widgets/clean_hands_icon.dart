import 'package:flutter/material.dart';

/// Hygiene / cleanliness marker. Uses a Material icon so it renders on every
/// device; the 🧤 emoji depends on system emoji fonts and often shows as □ or ?.
class CleanHandsIcon extends StatelessWidget {
  const CleanHandsIcon({super.key, this.size = 20});

  final double size;

  /// Matches cleanliness accent used elsewhere.
  static const Color kCleanlinessGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.clean_hands_rounded,
      color: kCleanlinessGreen,
      size: size,
    );
  }
}
