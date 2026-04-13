import 'package:flutter/material.dart';

/// Material 3 theme setup with runtime light/dark switching.
///
/// No [ThemeData.fontFamily] or [ThemeData.fontFamilyFallback] — uses platform
/// defaults (e.g. SF Pro + Apple Color Emoji on iOS, Roboto + Noto on Android)
/// so Khmer, emoji, and other scripts render correctly.
class AppTheme {
  AppTheme._();

  /// Material blue primary (buttons, selected nav, links) — explicit seed so M3
  /// does not fall back to a purple default on some platforms.
  static const Color _seedBlue = Color(0xFF1976D2);

  /// Global app theme mode state.
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedBlue,
          brightness: Brightness.light,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedBlue,
          brightness: Brightness.dark,
        ),
      );
}
