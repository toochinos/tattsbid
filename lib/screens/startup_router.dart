import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../core/locale/app_locale_controller.dart';
import '../core/services/language_service.dart';
import 'language_selection_screen.dart';
import 'login_page.dart';
import 'main_shell_page.dart';
import 'welcome_onboarding_page.dart';

// TEMP (testing): set to false before shipping — persist seenOnboarding = true (e.g. clear stuck “never finished”).
const bool _kResetSeenOnboardingPrefToTrue = false;

// TEMP (testing): set to false before shipping — always show onboarding this launch (in-memory only if pref reset above is true).
const bool _kForceShowOnboardingForTesting = false;

// TEMP (testing): set to false before shipping — clears persisted session so cold start never skips login.
const bool _kForceLogoutOnStartupForTesting = true;

/// Onboarding and language flags resolved in [main] before [runApp].
/// Session is read live in [StartupRouter.build].
class StartupSnapshot {
  const StartupSnapshot({
    required this.hasSeenOnboarding,
    required this.hasSelectedLanguage,
  });

  final bool hasSeenOnboarding;

  /// True when [LanguageService.preferenceKey] is set (non-empty).
  final bool hasSelectedLanguage;

  /// Prefs only (before first UI frame). Same key as onboarding completion.
  static Future<StartupSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final langRaw = prefs.getString(LanguageService.preferenceKey)?.trim();
    final hasSelectedLanguage = langRaw != null && langRaw.isNotEmpty;

    var hasSeenOnboarding = prefs.getBool('seenOnboarding') ?? false;
    if (!hasSeenOnboarding) {
      final legacy = prefs.getBool('has_seen_welcome') ?? false;
      if (legacy) {
        await prefs.setBool('seenOnboarding', true);
        hasSeenOnboarding = true;
      }
    }
    if (_kResetSeenOnboardingPrefToTrue) {
      await prefs.setBool('seenOnboarding', true);
      hasSeenOnboarding = true;
    }
    if (_kForceShowOnboardingForTesting) {
      hasSeenOnboarding = false;
    }

    return StartupSnapshot(
      hasSeenOnboarding: hasSeenOnboarding,
      hasSelectedLanguage: hasSelectedLanguage,
    );
  }
}

/// Run after [ensureSupabaseInitialized] (e.g. temp forced logout).
Future<void> applyStartupTestingAfterSupabase() async {
  if (!_kForceLogoutOnStartupForTesting) return;
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (_) {}
}

class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key, required this.snapshot});

  final StartupSnapshot snapshot;

  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  late bool _hasSeenOnboarding = widget.snapshot.hasSeenOnboarding;
  late bool _hasSelectedLanguage = widget.snapshot.hasSelectedLanguage;

  @override
  void initState() {
    super.initState();
    // [StartupSnapshot] is frozen from [main]; prefs may update (e.g. language)
    // before the widget tree rebuilds — resync once.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final hasLang = await LanguageService.hasLanguage();
      if (!mounted) return;
      if (hasLang && !_hasSelectedLanguage) {
        setState(() => _hasSelectedLanguage = true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant StartupRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.hasSeenOnboarding !=
        widget.snapshot.hasSeenOnboarding) {
      _hasSeenOnboarding = widget.snapshot.hasSeenOnboarding;
    }
    if (oldWidget.snapshot.hasSelectedLanguage !=
        widget.snapshot.hasSelectedLanguage) {
      _hasSelectedLanguage = widget.snapshot.hasSelectedLanguage;
    }
  }

  Future<void> _completeLanguageSelection(String code) async {
    await context
        .read<AppLocaleController>()
        .setLocale(Locale(code.trim()));
    if (!mounted) return;
    setState(() => _hasSelectedLanguage = true);
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
    if (!mounted) return;
    setState(() => _hasSeenOnboarding = true);
  }

  @override
  Widget build(BuildContext context) {
    final session = readSupabaseSessionIfReady();

    // 1) Image onboarding first (Skip / Get Started).
    // 2) Then language (English / Indonesian / Khmer).
    // 3) Then sign-in / main shell.
    if (!_hasSeenOnboarding) {
      return WelcomeOnboardingPage(onFinished: _completeOnboarding);
    }

    if (!_hasSelectedLanguage) {
      return LanguageSelectionScreen(
        onLanguageSelected: _completeLanguageSelection,
      );
    }

    if (session == null) {
      return const LoginPage();
    }

    return const MainShellPage();
  }
}
