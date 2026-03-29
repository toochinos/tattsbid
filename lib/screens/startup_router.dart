import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/routes/app_routes.dart';

// TEMP (testing): set to false before shipping — persist seenOnboarding = true (e.g. clear stuck “never finished”).
const bool _kResetSeenOnboardingPrefToTrue = true;

// TEMP (testing): set to false before shipping — always show onboarding this launch (in-memory only if pref reset above is true).
const bool _kForceShowOnboardingForTesting = true;

// TEMP (testing): set to false before shipping — clears persisted session so cold start never skips login.
const bool _kForceLogoutOnStartupForTesting = false;

/// Single startup control: onboarding flag + session → one of welcome / login / dashboard.
///
/// Used as [MaterialApp.home]. No `Navigator` decision should duplicate this logic elsewhere.
class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key});

  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_routeFromStartup());
    });
  }

  Future<void> _routeFromStartup() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    var hasSeenOnboarding = prefs.getBool('seenOnboarding') ?? false;
    if (!hasSeenOnboarding) {
      final legacy = prefs.getBool('has_seen_welcome') ?? false;
      if (legacy) {
        await prefs.setBool('seenOnboarding', true);
        if (!mounted) return;
        hasSeenOnboarding = true;
      }
    }
    if (_kResetSeenOnboardingPrefToTrue) {
      await prefs.setBool('seenOnboarding', true);
      if (!mounted) return;
      hasSeenOnboarding = true;
    }
    if (_kForceShowOnboardingForTesting) {
      hasSeenOnboarding = false;
    }
    if (!mounted) return;

    // Onboarding always wins — do not branch on session until this is true.
    if (!hasSeenOnboarding) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
      return;
    }

    if (_kForceLogoutOnStartupForTesting) {
      await Supabase.instance.client.auth.signOut();
    }
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (!mounted) return;

    if (session == null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.auth);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
