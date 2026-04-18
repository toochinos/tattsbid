import 'package:flutter/material.dart';

/// FLEXEMO “F” logo (transparent PNG). [size] is the layout width and height.
///
/// Pass [color] (with [colorBlendMode], default [BlendMode.srcIn]) to draw the
/// mark in a single flat color like a standard bottom-bar icon.
class FlexemoMark extends StatelessWidget {
  const FlexemoMark({
    super.key,
    required this.size,
    this.color,
    this.colorBlendMode = BlendMode.srcIn,
    this.errorFallback,
  });

  final double size;

  /// When set, tints the asset (same idea as [IconTheme] / [Icon.color]).
  final Color? color;
  final BlendMode colorBlendMode;

  /// Shown if the asset fails to load (e.g. missing from bundle).
  final Widget? errorFallback;

  static const String assetPath = 'assets/icons/flexemo_tab_icon.png';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        color: color,
        colorBlendMode: color == null ? null : colorBlendMode,
        errorBuilder: (_, __, ___) =>
            errorFallback ??
            Icon(
              Icons.photo_library_outlined,
              size: size * 0.85,
              color: color ?? scheme.primary,
            ),
      ),
    );
  }
}
