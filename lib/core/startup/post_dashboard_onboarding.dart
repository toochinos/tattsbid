import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/link_handler.dart';
import '../routes/app_routes.dart';
import '../services/onboarding_service.dart';

/// Agreement / profile checks that require network — run only after [MainShellPage] is visible.
class PostDashboardOnboarding {
  PostDashboardOnboarding._();

  /// Call from dashboard after first frame. Safe to call multiple times (guarded).
  static void scheduleAfterFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(run());
    });
  }

  static bool _inFlight = false;

  static Future<void> run() async {
    if (_inFlight) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _inFlight = true;
    try {
      await Future<void>.delayed(Duration.zero);
      for (var i = 0; i < 40; i++) {
        final ctx = LinkHandler.navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) break;
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }

      final sw = Stopwatch()..start();
      final needsAgreement = await OnboardingService.needsAgreement();
      if (kDebugMode) {
        debugPrint(
          '[Startup] post-dashboard needsAgreement ${sw.elapsedMilliseconds}ms → '
          '$needsAgreement',
        );
      }
      var navContext = LinkHandler.navigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) return;
      if (needsAgreement) {
        Navigator.of(navContext, rootNavigator: true).pushReplacementNamed(
          AppRoutes.userAgreement,
          arguments: const {
            'nextRoute': AppRoutes.profile,
            'nextArgs': {'fromSignUp': true, 'allowAccountTypeChoice': true},
          },
        );
        return;
      }

      sw.reset();
      final needsProfileSetup = await OnboardingService.needsProfileSetup();
      if (kDebugMode) {
        debugPrint(
          '[Startup] post-dashboard needsProfileSetup ${sw.elapsedMilliseconds}ms → '
          '$needsProfileSetup',
        );
      }
      navContext = LinkHandler.navigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) return;
      if (needsProfileSetup) {
        Navigator.of(navContext, rootNavigator: true).pushReplacementNamed(
          AppRoutes.profile,
          arguments: const {
            'fromSignUp': true,
            'allowAccountTypeChoice': true,
          },
        );
      }
    } finally {
      _inFlight = false;
    }
  }
}
