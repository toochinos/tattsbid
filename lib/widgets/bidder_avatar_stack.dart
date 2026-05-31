import 'package:flutter/material.dart';

/// Overlapping bidder avatars with a total count label (explore bid cards).
class BidderAvatarStack extends StatelessWidget {
  const BidderAvatarStack({
    super.key,
    required this.avatarUrls,
    required this.totalCount,
    required this.label,
    this.labelStyle,
    this.avatarSize = 20,
    this.overlap = 7,
  });

  /// Up to three entries; empty string means show a placeholder avatar.
  final List<String> avatarUrls;

  final int totalCount;
  final String label;
  final TextStyle? labelStyle;
  final double avatarSize;
  final double overlap;

  @override
  Widget build(BuildContext context) {
    if (totalCount <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final muted = theme.colorScheme.outline;
    final textStyle =
        labelStyle ?? theme.textTheme.labelSmall?.copyWith(color: muted);
    final shown = avatarUrls.isEmpty ? 1 : avatarUrls.length.clamp(1, 3);
    final urls = avatarUrls.take(3).toList();
    while (urls.length < shown) {
      urls.add('');
    }
    final stackWidth = avatarSize + (shown - 1) * (avatarSize - overlap);

    return Row(
      children: [
        SizedBox(
          width: stackWidth,
          height: avatarSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < shown; i++)
                Positioned(
                  left: i * (avatarSize - overlap),
                  child: _BidderAvatar(
                    url: urls[i],
                    size: avatarSize,
                    borderColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _BidderAvatar extends StatelessWidget {
  const _BidderAvatar({
    required this.url,
    required this.size,
    required this.borderColor,
  });

  final String url;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    final hasPhoto = trimmed.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        backgroundImage: hasPhoto ? NetworkImage(trimmed) : null,
        child: hasPhoto
            ? null
            : Icon(
                Icons.person,
                size: size * 0.55,
                color: Theme.of(context).colorScheme.outline,
              ),
      ),
    );
  }
}
