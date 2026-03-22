import 'package:flutter/material.dart';

/// Material 3 theme — **light / white only** (no dark mode).
class AppTheme {
  AppTheme._();

  /// Forces white surfaces and light brightness app-wide.
  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ).copyWith(
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      );

  /// Same as [light] — used so `darkTheme` cannot apply a dark palette.
  static ThemeData get darkFallback => light;
}
