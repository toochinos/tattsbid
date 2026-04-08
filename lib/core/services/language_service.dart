import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences access for the chosen app language (no auth required).
/// Runtime locale updates use [AppLocaleController] ([notifyListeners]).
class LanguageService {
  LanguageService._();

  /// SharedPreferences key used by [getSavedLanguage] and [AppLocaleController].
  static const String preferenceKey = 'app_language';

  static Future<String?> getSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(preferenceKey);
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static Future<bool> hasLanguage() async {
    final v = await getSavedLanguage();
    return v != null;
  }
}
