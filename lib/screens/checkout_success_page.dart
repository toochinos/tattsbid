import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../core/services/subscription_service.dart';

/// Shown when user returns from Stripe checkout (success).
/// Confirms the session, refreshes subscription state, then navigates.
class CheckoutSuccessPage extends StatefulWidget {
  const CheckoutSuccessPage({
    super.key,
    required this.sessionId,
  });

  final String sessionId;

  @override
  State<CheckoutSuccessPage> createState() => _CheckoutSuccessPageState();
}

class _CheckoutSuccessPageState extends State<CheckoutSuccessPage> {
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _confirmAndNavigate();
  }

  Future<void> _confirmAndNavigate() async {
    try {
      await SubscriptionService.confirmCheckout(widget.sessionId);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.dashboard,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(context)
                            .pushNamed(AppRoutes.dashboard),
                        child: const Text('Continue'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
      ),
    );
  }
}
