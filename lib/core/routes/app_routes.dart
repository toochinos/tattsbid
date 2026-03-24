import 'package:flutter/material.dart';

import '../../screens/auth_screen.dart';
import '../../screens/splash_screen.dart';
import '../../screens/checkout_cancel_page.dart';
import '../../screens/checkout_success_page.dart';
import '../../screens/edit_profile_page.dart';
import '../../screens/landing_page.dart';
import '../../screens/main_shell_page.dart';
import '../../screens/login_page.dart';
import '../../screens/paywall_page.dart';
import '../../screens/profile_screen.dart';
import '../../screens/settings_page.dart';
import '../../screens/sign_up_page.dart';

/// Central place for route names and route map.
/// Use [AppRoutes.landing] etc. and [AppRoutes.routes] for [MaterialApp.routes].
class AppRoutes {
  AppRoutes._();

  /// Initial route: redirects to dashboard or landing based on auth.
  static const String root = '/';
  static const String landing = '/landing';
  static const String login = '/login';
  static const String signUp = '/sign-up';
  static const String dashboard = '/dashboard';
  static const String paywall = '/paywall';
  static const String settings = '/settings';
  static const String checkoutSuccess = '/checkout/success';
  static const String checkoutCancel = '/checkout/cancel';
  static const String editProfile = '/profile/edit';
  static const String auth = '/auth';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> get routes => {
        root: (_) => const SplashScreen(),
        landing: (_) => const LandingPage(),
        login: (_) => const LoginPage(),
        signUp: (_) => const SignUpPage(),
        auth: (_) => const AuthScreen(),
        dashboard: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final openChat = args is Map && args['openChat'] == true;
          final receiverId = args is Map ? args['receiverId'] as String? : null;
          final openWinnerProfile =
              args is Map && args['openWinnerProfile'] == true;
          final refreshExplore =
              args is Map && args['refreshExplore'] == true;
          return MainShellPage(
            openChatOnLaunch: openChat,
            initialChatReceiverId: receiverId,
            openWinnerProfileOnLaunch: openWinnerProfile,
            refreshExploreOnLaunch: refreshExplore,
          );
        },
        paywall: (_) => const PaywallPage(),
        settings: (_) => const SettingsPage(),
        checkoutCancel: (_) => const CheckoutCancelPage(),
      };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == checkoutSuccess) {
      final args = settings.arguments;
      String? sessionId;
      var kind = 'subscription';
      String? receiverId;
      if (args is String) {
        sessionId = args;
      } else if (args is Map) {
        sessionId = args['sessionId'] as String?;
        kind = args['kind'] as String? ?? 'subscription';
        receiverId = args['receiverId'] as String?;
      }
      if (sessionId != null && sessionId.isNotEmpty) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => CheckoutSuccessPage(
            sessionId: sessionId!,
            kind: kind,
            receiverId: receiverId,
          ),
        );
      }
    }
    if (settings.name == editProfile) {
      final fromSignUp = settings.arguments == true;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => EditProfilePage(fromSignUp: fromSignUp),
      );
    }
    if (settings.name == profile) {
      final args = settings.arguments;
      var fromSignUp = false;
      var allowAccountTypeChoice = false;
      if (args is Map) {
        fromSignUp = args['fromSignUp'] == true;
        allowAccountTypeChoice = args['allowAccountTypeChoice'] == true;
      } else if (args == true) {
        fromSignUp = true;
        allowAccountTypeChoice = true;
      }
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => ProfileScreen(
          fromSignUp: fromSignUp,
          allowAccountTypeChoice: allowAccountTypeChoice || fromSignUp,
        ),
      );
    }
    return null;
  }
}
