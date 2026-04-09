import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../l10n/app_localizations.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.auth),
              child: Text(l10n.authTabLogin),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.auth),
              child: Text(l10n.authTabSignUp),
            ),
          ],
        ),
      ),
    );
  }
}
