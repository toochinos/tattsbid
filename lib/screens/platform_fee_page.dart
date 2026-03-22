import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_constants.dart';
import '../core/payment/pending_deposit_payment.dart';
import '../core/services/payment_service.dart';

class PlatformFeePage extends StatelessWidget {
  final String requestId;
  final String bidId;
  final String? artistUserId;
  final double bidAmount;
  final double platformFee;
  final double total;

  const PlatformFeePage({
    super.key,
    required this.requestId,
    required this.bidId,
    this.artistUserId,
    required this.bidAmount,
    required this.platformFee,
    required this.total,
  });

  Future<void> _startStripeCheckout(BuildContext context) async {
    try {
      // So CheckoutSuccessPage can mark this request completed after Stripe returns.
      PendingDepositPayment.requestId = requestId;
      PendingDepositPayment.artistUserId = artistUserId;
      PendingDepositPayment.depositAmount = platformFee;
      final uid = Supabase.instance.client.auth.currentUser?.id;
      await startPayment(
        amount: platformFee,
        bidId: bidId,
        receiverId: artistUserId,
        requestId: requestId,
        userId: uid,
        depositAmount: platformFee,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final artistPayout = total - platformFee;
    return Scaffold(
      appBar: AppBar(title: const Text("Deposit summary")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Total cost: \$${total.toStringAsFixed(2)}"),
            Text(
              "Deposit fee ${AppConstants.platformFeePercent}%: \$${platformFee.toStringAsFixed(2)}",
            ),
            Text("Artist receives: \$${artistPayout.toStringAsFixed(2)}"),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  print("🔥 BUTTON CLICKED");
                  await _startStripeCheckout(context);
                },
                child: const Text("Pay"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
