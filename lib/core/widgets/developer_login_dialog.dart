import 'package:flutter/material.dart';

/// Hidden developer password gate (Settings → 5× tap copyright).
class DeveloperLoginDialog {
  DeveloperLoginDialog._();

  // TODO: Replace hardcoded password with secure Supabase-based admin
  // authentication before public launch.
  static const String password = 'ilovetattsbiddev';

  static const Duration _routeSettleDelay = Duration(milliseconds: 100);

  /// Shows the password dialog. Does not navigate.
  static Future<DeveloperLoginResult> prompt(BuildContext context) async {
    final controller = TextEditingController();
    try {
      final submitted = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Developer access'),
            content: TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );

      // Dialog route has popped; allow the overlay to finish closing.
      await Future<void>.delayed(_routeSettleDelay);

      final enteredPassword = controller.text;
      if (submitted != true) {
        debugPrint('Developer login: cancelled');
        return DeveloperLoginResult.cancelled;
      }
      if (enteredPassword != password) {
        debugPrint('Developer login: incorrect password');
        return DeveloperLoginResult.wrongPassword;
      }
      debugPrint('Developer login: password accepted');
      return DeveloperLoginResult.success;
    } finally {
      controller.dispose();
    }
  }
}

enum DeveloperLoginResult {
  cancelled,
  wrongPassword,
  success,
}
