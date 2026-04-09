import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../l10n/app_localizations.dart';

/// Shown when user cancels Stripe checkout.
class CheckoutCancelPage extends StatelessWidget {
  const CheckoutCancelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkoutTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.checkoutCancelledMessage),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.paywall),
              child: Text(l10n.checkoutTryAgain),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context)
                  .pushReplacementNamed(AppRoutes.dashboard),
              child: Text(l10n.checkoutBackToDashboard),
            ),
          ],
        ),
      ),
    );
  }
}
