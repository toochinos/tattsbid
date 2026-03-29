import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user finished the one-time onboarding carousel.
class WelcomePrefsService {
  WelcomePrefsService._();

  static const String _keySeenOnboarding = 'seenOnboarding';

  /// Legacy key from older builds; migrated once into [_keySeenOnboarding].
  static const String _keyLegacyWelcome = 'has_seen_welcome';

  static Future<bool> get hasSeenOnboarding async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getBool(_keySeenOnboarding);
    if (current != null) {
      return current;
    }
    final legacy = prefs.getBool(_keyLegacyWelcome) ?? false;
    if (legacy) {
      await prefs.setBool(_keySeenOnboarding, true);
    }
    return legacy;
  }

  static Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySeenOnboarding, true);
  }
}
