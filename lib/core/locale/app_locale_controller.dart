import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/language_service.dart';

/// Drives [MaterialApp.locale] and persists [LanguageService.preferenceKey].
/// Use with [ChangeNotifierProvider] + [Consumer]; call [setLocale] (or
/// [setLanguage]) to update the UI immediately ([notifyListeners]).
class AppLocaleController extends ChangeNotifier {
  AppLocaleController();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('km'),
    Locale('id'),
  ];

  Locale _locale = supportedLocales.first;
  Locale get locale => _locale;

  bool _isSupportedCode(String code) =>
      supportedLocales.any((l) => l.languageCode == code);

  /// Load saved code from prefs (or keep English). Call before [runApp].
  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(LanguageService.preferenceKey)?.trim();
    if (raw != null && raw.isNotEmpty && _isSupportedCode(raw)) {
      _locale = Locale(raw);
    } else {
      _locale = supportedLocales.first;
    }
    notifyListeners();
  }

  /// Persists the locale’s language code and rebuilds the app tree.
  Future<void> setLocale(Locale locale) async {
    final code = locale.languageCode.trim();
    if (!_isSupportedCode(code)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LanguageService.preferenceKey, code);
    _locale = Locale(code);
    notifyListeners();
  }

  /// Same as [setLocale] with a raw code string (`en` / `km` / `id`).
  Future<void> setLanguage(String languageCode) async {
    await setLocale(Locale(languageCode.trim()));
  }
}
