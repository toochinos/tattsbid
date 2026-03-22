import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';

/// Calls the pay API and opens the Stripe checkout URL in the browser.
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
  print("🚀 startPayment called");
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

  print("📡 sending request...");
  final response = await http.post(
    AppConstants.payUrl,
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
