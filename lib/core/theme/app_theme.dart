import 'package:flutter/material.dart';

/// Material 3 theme setup with runtime light/dark switching.
///
/// No [ThemeData.fontFamily] or [ThemeData.fontFamilyFallback] — uses platform
/// defaults (e.g. SF Pro + Apple Color Emoji on iOS, Roboto + Noto on Android)
/// so Khmer, emoji, and other scripts render correctly.
class AppTheme {
  AppTheme._();

  /// Global app theme mode state.
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      );
}
