import 'package:flutter/material.dart';

import '../core/utils/user_type_utils.dart';
import '../l10n/app_localizations.dart';

/// Subtitle for [userType] using the same copy as the profile account-type labels.
String? userRoleLabelForType(
  BuildContext context,
  String? rawUserType, {
  bool compact = false,
}) {
  final c = canonicalUserType(rawUserType);
  if (c == null) return null;
  final l10n = AppLocalizations.of(context)!;
  if (c == 'tattoo_artist') {
    return compact
        ? l10n.bidDetailArtistNameFallback
        : l10n.profileTattooArtistTitle;
  }
  if (c == 'customer') return l10n.profileCustomerTitle;
  return null;
}

/// Primary name with an optional role: on a second line, or inline when [compactRole] is true.
class UserNameWithRole extends StatelessWidget {
  const UserNameWithRole({
    super.key,
    required this.name,
    this.userType,
    this.compactRole = false,
    this.nameStyle,
    this.roleStyle,
    this.nameStrutStyle,
    this.roleStrutStyle,
    this.textAlign = TextAlign.start,
    this.maxNameLines = 1,
  });

  final String name;
  final String? userType;

  /// When true, artists show as "Artist" (e.g. explore cards) not "Tattoo artist".
  final bool compactRole;
  final TextStyle? nameStyle;
  final TextStyle? roleStyle;
  final StrutStyle? nameStrutStyle;
  final StrutStyle? roleStrutStyle;
  final TextAlign textAlign;
  final int maxNameLines;

  @override
  Widget build(BuildContext context) {
    final role = userRoleLabelForType(context, userType, compact: compactRole);
    final resolvedRoleStyle = roleStyle ??
        Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            );

    if (compactRole && role != null) {
      return Row(
        mainAxisAlignment: _mainAxisForAlign(textAlign),
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: Text(
              name,
              style: nameStyle,
              strutStyle: nameStrutStyle,
              textAlign: textAlign,
              maxLines: maxNameLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            role,
            style: resolvedRoleStyle,
            strutStyle: roleStrutStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _crossForAlign(textAlign),
      children: [
        Text(
          name,
          style: nameStyle,
          strutStyle: nameStrutStyle,
          textAlign: textAlign,
          maxLines: maxNameLines,
          overflow: TextOverflow.ellipsis,
        ),
        if (role != null) ...[
          const SizedBox(height: 2),
          Text(
            role,
            style: resolvedRoleStyle,
            strutStyle: roleStrutStyle,
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  MainAxisAlignment _mainAxisForAlign(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return MainAxisAlignment.center;
      case TextAlign.end:
      case TextAlign.right:
        return MainAxisAlignment.end;
      default:
        return MainAxisAlignment.start;
    }
  }

  CrossAxisAlignment _crossForAlign(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return CrossAxisAlignment.center;
      case TextAlign.end:
      case TextAlign.right:
        return CrossAxisAlignment.end;
      default:
        return CrossAxisAlignment.start;
    }
  }
}
