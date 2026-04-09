import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_constants.dart';
import '../core/payment/pending_deposit_payment.dart';
import '../core/services/payment_service.dart';
import '../core/services/payment_status_service.dart';
import '../l10n/app_localizations.dart';

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
      if (!context.mounted) return;
      await PaymentStatusService.checkPaymentStatusAfterCheckoutLaunched(
        context,
        requestId,
      );
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.platformFeePaymentFailed(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final artistPayout = total - platformFee;
    final totalStr = '\$${total.toStringAsFixed(2)}';
    final feeStr = '\$${platformFee.toStringAsFixed(2)}';
    final payoutStr = '\$${artistPayout.toStringAsFixed(2)}';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.depositSummaryTitle)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(l10n.depositTotalCostLine(totalStr)),
            Text(
              l10n.depositFeePercentLine(
                AppConstants.platformFeePercent,
                feeStr,
              ),
            ),
            Text(l10n.depositArtistReceivesLine(payoutStr)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  print("🔥 BUTTON CLICKED");
                  await _startStripeCheckout(context);
                },
                child: Text(l10n.depositPayButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
