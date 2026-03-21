import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../core/services/subscription_service.dart';

/// Shown when user returns from Stripe checkout (success).
/// Confirms the session, refreshes subscription state, then navigates.
class CheckoutSuccessPage extends StatefulWidget {
  const CheckoutSuccessPage({
    super.key,
    required this.sessionId,
    this.kind = 'subscription',
    this.receiverId,
  });

  final String sessionId;

  /// `deposit` = pay API / tattoo bid; `subscription` = Supabase confirm-checkout.
  final String kind;
  final String? receiverId;

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
      // Deposit (Stripe Checkout from Node /api/pay):
      // After returning to the app (e.g. "Open in SaaS App"), show the winner's profile.
      if (widget.kind == 'deposit') {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.dashboard,
          (route) => false,
          arguments: <String, dynamic>{
            'openWinnerProfile': true,
            'receiverId': widget.receiverId,
          },
        );
        return;
      }

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
