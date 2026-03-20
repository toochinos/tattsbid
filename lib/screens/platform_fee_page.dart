import 'package:flutter/material.dart';

import '../core/services/payment_service.dart';

class PlatformFeePage extends StatelessWidget {
  final String requestId;
  final String bidId;
  final double bidAmount;
  final double platformFee;
  final double total;

  const PlatformFeePage({
    super.key,
    required this.requestId,
    required this.bidId,
    required this.bidAmount,
    required this.platformFee,
    required this.total,
  });

  Future<void> _startStripeCheckout(BuildContext context) async {
    try {
      await startPayment(amount: platformFee, bidId: bidId);
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
      appBar: AppBar(title: const Text("Payment Summary")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Total cost: \$${total.toStringAsFixed(2)}"),
            Text("Platform fee (8%): \$${platformFee.toStringAsFixed(2)}"),
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
