import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/payment/pending_deposit_payment.dart';
import '../core/routes/app_routes.dart';
import '../core/services/payment_status_service.dart';
import '../core/services/payment_service.dart';
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

  /// `deposit` = tattoo bid deposit via Node `/create-payment` + `/verify-payment`.
  /// `subscription` = Supabase confirm-checkout.
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

  /// Server-side unlock (Supabase service role) — retry while Stripe finalizes payment.
  Future<void> _verifyUnlockOnServer() async {
    for (var i = 0; i < 5; i++) {
      try {
        final r = await verifyDepositCheckoutSession(widget.sessionId);
        if (r.paid) return;
      } catch (e, st) {
        debugPrint('verify-payment attempt ${i + 1}: $e\n$st');
      }
      await Future<void>.delayed(Duration(milliseconds: 600 + i * 400));
    }
  }

  Future<void> _confirmAndNavigate() async {
    try {
      if (widget.kind == 'deposit') {
        final pendingRequestId = PendingDepositPayment.requestId;
        final pendingArtistId = PendingDepositPayment.artistUserId;
        final artistIdForUnlock =
            (widget.receiverId != null && widget.receiverId!.trim().isNotEmpty)
                ? widget.receiverId!.trim()
                : (pendingArtistId != null && pendingArtistId.trim().isNotEmpty
                    ? pendingArtistId.trim()
                    : null);

        await _verifyUnlockOnServer();

        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null &&
            pendingRequestId != null &&
            pendingRequestId.isNotEmpty &&
            artistIdForUnlock != null &&
            artistIdForUnlock.isNotEmpty) {
          try {
            await postDepositSuccessRecord(
              userId: uid,
              requestId: pendingRequestId,
              artistId: artistIdForUnlock,
            );
          } catch (e, st) {
            debugPrint('POST /success (unlock record): $e\n$st');
          }
        }

        if (pendingRequestId != null && pendingRequestId.isNotEmpty) {
          try {
            await TattooRequestService.markRequestCompletedAfterPayment(
              requestId: pendingRequestId,
            );
          } catch (e, st) {
            debugPrint('markRequestCompletedAfterPayment: $e\n$st');
          }
        }

        final requestIdAfterPay = pendingRequestId?.trim() ?? '';
        PendingDepositPayment.clear();

        if (!mounted) return;
        // Poll Supabase while this route is still on the stack (reliable Navigator context).
        if (requestIdAfterPay.isNotEmpty) {
          await PaymentStatusService.checkPaymentStatus(
            context,
            requestIdAfterPay,
          );
        }
        if (!mounted) return;
        setState(() => _loading = false);
        await Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.dashboard,
          (route) => false,
          arguments: <String, dynamic>{
            'openChat': true,
            'receiverId': artistIdForUnlock ?? widget.receiverId,
            'refreshExplore': true,
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
