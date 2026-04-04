import 'package:flutter/material.dart';

import 'clean_hands_icon.dart';

/// Gold stars for overall experience.
class TattooExperienceStarBar extends StatelessWidget {
  const TattooExperienceStarBar({
    super.key,
    required this.value,
    this.size = 20,
  });

  final int value;
  final double size;

  static const Color _gold = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context) {
    final empty = Theme.of(context).colorScheme.outline.withValues(alpha: 0.35);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          Icons.star_rounded,
          color: i < value.clamp(0, 5) ? _gold : empty,
          size: size,
        ),
      ),
    );
  }
}

/// Green stars for cleanliness (hygiene / studio).
class TattooCleanlinessStarBar extends StatelessWidget {
  const TattooCleanlinessStarBar({
    super.key,
    required this.value,
    this.size = 20,
  });

  final int value;
  final double size;

  static const Color _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final empty = Theme.of(context).colorScheme.outline.withValues(alpha: 0.35);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          Icons.star_rounded,
          color: i < value.clamp(0, 5) ? _green : empty,
          size: size,
        ),
      ),
    );
  }
}

OutlineInputBorder _reviewFieldBorder(ColorScheme scheme) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
  );
}

/// Interactive 1–5 stars inside a field that matches the review comment [TextField].
class TattooExperienceStarPicker extends StatelessWidget {
  const TattooExperienceStarPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.starSize = 34,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final double starSize;

  static const Color _gold = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Rating',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: Icon(Icons.star_rounded, color: _gold, size: 22),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 44, minHeight: 44),
        border: _reviewFieldBorder(scheme),
        enabledBorder: _reviewFieldBorder(scheme),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final star = i + 1;
            final filled = star <= value;
            return IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                  width: starSize + 8, height: starSize + 8),
              onPressed: !enabled ? null : () => onChanged(star),
              icon: Icon(
                Icons.star_rounded,
                color: filled ? _gold : scheme.outline.withValues(alpha: 0.45),
                size: starSize,
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Interactive 1–5 stars for cleanliness inside a field matching the comment [TextField].
class TattooCleanlinessStarPicker extends StatelessWidget {
  const TattooCleanlinessStarPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.starSize = 34,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final double starSize;

  static const Color _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Cleanliness',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: _green,
              fontWeight: FontWeight.w600,
            ),
        prefixIcon: const Padding(
          padding: EdgeInsetsDirectional.only(start: 8),
          child: CleanHandsIcon(size: 22),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 44, minHeight: 44),
        border: _reviewFieldBorder(scheme),
        enabledBorder: _reviewFieldBorder(scheme),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final star = i + 1;
            final filled = star <= value;
            return IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                  width: starSize + 8, height: starSize + 8),
              onPressed: !enabled ? null : () => onChanged(star),
              icon: Icon(
                Icons.star_rounded,
                color: filled ? _green : scheme.outline.withValues(alpha: 0.45),
                size: starSize,
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Side-by-side summary: Rating + stars | Cleanliness + stars.
class TattooDualRatingAveragesHeader extends StatelessWidget {
  const TattooDualRatingAveragesHeader({
    super.key,
    required this.experienceAverage,
    required this.cleanlinessAverage,
  });

  final double experienceAverage;
  final double cleanlinessAverage;

  static const Color _gold = Color(0xFFFFC107);
  static const Color _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    // Explicit styles avoid theme TextStyle merges where a bad `height` etc.
    // could surface as bool vs double? at runtime.
    const style = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    final expStars =
        experienceAverage.round().clamp(1, 5).toInt();
    final cleanStars =
        cleanlinessAverage.round().clamp(1, 5).toInt();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(Icons.star_rounded, color: _gold, size: 22),
                  Text(' Rating: ', style: style),
                  Text(
                    experienceAverage.toStringAsFixed(1),
                    style: style,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: TattooExperienceStarBar(
                  value: expStars,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const CleanHandsIcon(size: 20),
                  Text(
                    ' Cleanliness: ',
                    style: style.copyWith(color: _green),
                  ),
                  Text(
                    cleanlinessAverage.toStringAsFixed(1),
                    style: style.copyWith(color: _green),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: TattooCleanlinessStarBar(
                  value: cleanStars,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
