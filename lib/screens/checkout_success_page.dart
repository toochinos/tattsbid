import 'package:flutter/material.dart';

import '../core/payment/pending_deposit_payment.dart';
import '../core/routes/app_routes.dart';
import '../core/services/contact_unlock_service.dart';
import '../core/services/subscription_service.dart';
import '../core/services/tattoo_request_service.dart';

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
        final pendingRequestId = PendingDepositPayment.requestId;
        final pendingArtistId = PendingDepositPayment.artistUserId;
        final artistIdForUnlock =
            (widget.receiverId != null && widget.receiverId!.trim().isNotEmpty)
                ? widget.receiverId!.trim()
                : (pendingArtistId != null && pendingArtistId.trim().isNotEmpty
                    ? pendingArtistId.trim()
                    : null);
        if (pendingRequestId != null && pendingRequestId.isNotEmpty) {
          try {
            await TattooRequestService.markRequestCompletedAfterPayment(
              requestId: pendingRequestId,
            );
            if (artistIdForUnlock != null && artistIdForUnlock.isNotEmpty) {
              try {
                await ContactUnlockService.recordUnlockAfterSuccessfulPayment(
                  requestId: pendingRequestId,
                  artistId: artistIdForUnlock,
                  depositAmount: PendingDepositPayment.depositAmount,
                );
              } catch (e, st) {
                debugPrint('record_contact_unlock: $e\n$st');
              }
            }
          } catch (_) {
            // RLS or network; user can still continue — status may update on retry.
          } finally {
            PendingDepositPayment.clear();
          }
        }
        if (!mounted) return;
        // Open Message tab with the winning artist so the customer can chat
        // immediately after the Stripe deposit (receiver_id from checkout redirect).
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.dashboard,
          (route) => false,
          arguments: <String, dynamic>{
            'openChat': true,
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
