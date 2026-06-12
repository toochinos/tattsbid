import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../l10n/app_localizations.dart';
import 'auth_screen.dart';

/// Same UI as [AuthScreen]: **Login** and **Sign up** in one screen (tab bar).
///
/// Used after onboarding and from [AppRoutes.login]; cold start unauthenticated
/// flow uses [AppRoutes.auth] which is also [AuthScreen].
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowAccountDeletedMessage();
    });
  }

  void _maybeShowAccountDeletedMessage() {
    if (!mounted) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map || args[AppRoutes.showAccountDeletedMessageArg] != true) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.accountDeletionSuccessMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const AuthScreen();
}
