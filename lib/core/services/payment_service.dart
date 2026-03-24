import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';

/// Calls the pay API and opens the Stripe checkout URL in the browser.
///
/// **Completes when the checkout URL is opened**, not when the user finishes paying.
/// After this returns, call [PaymentStatusService.checkPaymentStatusAfterCheckoutLaunched]
/// (or run [PaymentStatusService.checkPaymentStatus] from [CheckoutSuccessPage]).
/// [amount] is the deposit fee in dollars. [bidId] is optional and sent as metadata.
/// [requestId] and [userId] are stored on the Stripe session so the Node server
/// can insert [contact_unlocks] after verified payment.
/// [depositAmount] is persisted as [contact_unlocks.deposit_amount] (same as [amount] for 10% flow).
Future<void> startPayment({
  required double amount,
  String? bidId,
  String? receiverId,
  String? requestId,
  String? userId,
  double? depositAmount,
}) async {
  final body = <String, dynamic>{'amount': amount};
  if (bidId != null) body['bid_id'] = bidId;
  if (receiverId != null && receiverId.trim().isNotEmpty) {
    body['receiver_id'] = receiverId.trim();
  }
  if (requestId != null && requestId.trim().isNotEmpty) {
    body['request_id'] = requestId.trim();
  }
  if (userId != null && userId.trim().isNotEmpty) {
    body['user_id'] = userId.trim();
  }
  if (depositAmount != null) {
    body['deposit_amount'] = depositAmount;
  }

  // Same URI as POST — only [AppConstants.payUrl] (see payApiPath = /create-payment, not /api/pay).
  final uri = AppConstants.payUrl;
  print('CALLING API: $uri');
  final response = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );

  print(response.body);

  final data = jsonDecode(response.body) as Map<String, dynamic>?;

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(data?['error'] ?? response.body);
  }

  if (data != null && data['url'] != null) {
    final url = data['url'] as String;
    print("STRIPE URL: $url");
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } else {
    throw Exception(data?['error'] ?? response.body);
  }
}

/// Backend confirms Stripe Checkout and writes [contact_unlocks] (service role on server).
Future<DepositVerifyResult> verifyDepositCheckoutSession(String sessionId) async {
  final trimmed = sessionId.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('sessionId required');
  }
  final response = await http.post(
    AppConstants.verifyPaymentUrl,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(<String, dynamic>{'session_id': trimmed}),
  );
  final data = jsonDecode(response.body) as Map<String, dynamic>?;
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(data?['error'] ?? response.body);
  }
  final paid = data?['paid'] == true;
  return DepositVerifyResult(
    ok: data?['ok'] == true,
    paid: paid,
    paymentStatus: data?['payment_status'] as String?,
  );
}

class DepositVerifyResult {
  const DepositVerifyResult({
    required this.ok,
    required this.paid,
    this.paymentStatus,
  });

  final bool ok;
  final bool paid;
  final String? paymentStatus;
}

/// `POST /success` — upserts [contact_unlocks] and sets [bids.payment_status] (Node + service role).
Future<void> postDepositSuccessRecord({
  required String userId,
  required String requestId,
  required String artistId,
}) async {
  final response = await http.post(
    Uri.parse('${AppConstants.apiBaseUrl}/success'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(<String, dynamic>{
      'user_id': userId,
      'request_id': requestId,
      'artist_id': artistId,
    }),
  );
  final data = jsonDecode(response.body) as Map<String, dynamic>?;
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(data?['error'] ?? response.body);
  }
}
