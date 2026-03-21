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

    if (_isCheckoutSuccess(uri)) {
      final sessionId = uri.queryParameters['session_id'];
      final kind = uri.queryParameters['kind'] ?? 'subscription';
      final receiverId = uri.queryParameters['receiver_id'];
      if (sessionId != null && sessionId.isNotEmpty) {
        final args = <String, String>{
          'sessionId': sessionId,
          'kind': kind,
        };
        if (receiverId != null && receiverId.trim().isNotEmpty) {
          args['receiverId'] = receiverId.trim();
        }
        nav.pushNamed(
          AppRoutes.checkoutSuccess,
          arguments: args,
        );
      }
    } else if (_isCheckoutCancel(uri)) {
      nav.pushNamed(AppRoutes.checkoutCancel);
    }
  }

  /// HTTPS paths or `tattsbid://checkout/success?...` after Stripe redirect.
  static bool _isCheckoutSuccess(Uri uri) {
    if (uri.path.contains('checkout/success')) return true;
    return uri.scheme == 'tattsbid' &&
        uri.host == 'checkout' &&
        uri.path == '/success';
  }

  static bool _isCheckoutCancel(Uri uri) {
    if (uri.path.contains('checkout/cancel')) return true;
    return uri.scheme == 'tattsbid' &&
        uri.host == 'checkout' &&
        uri.path == '/cancel';
  }

  static void dispose() {
    _linkSubscription?.cancel();
  }
}
