import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../routes/app_routes.dart';

/// Handles incoming app links (Stripe checkout success/cancel redirects).
class LinkHandler {
  LinkHandler._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final AppLinks _appLinks = AppLinks();

  static StreamSubscription<Uri>? _linkSubscription;

  /// Initialize link handling. Call from app init.
  static void init() {
    _linkSubscription?.cancel();
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleLink);
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleLink(uri);
      }
    });
  }

  static void _handleLink(Uri uri) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    if (uri.path.contains('checkout/success')) {
      final sessionId = uri.queryParameters['session_id'];
      if (sessionId != null && sessionId.isNotEmpty) {
        nav.pushNamed(AppRoutes.checkoutSuccess, arguments: sessionId);
      }
    } else if (uri.path.contains('checkout/cancel')) {
      nav.pushNamed(AppRoutes.checkoutCancel);
    }
  }

  static void dispose() {
    _linkSubscription?.cancel();
  }
}
