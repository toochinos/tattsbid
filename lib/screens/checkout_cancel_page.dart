import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';

/// Shown when user cancels Stripe checkout.
class CheckoutCancelPage extends StatelessWidget {
  const CheckoutCancelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Checkout was cancelled.'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.paywall),
              child: const Text('Try again'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context)
                  .pushReplacementNamed(AppRoutes.dashboard),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
