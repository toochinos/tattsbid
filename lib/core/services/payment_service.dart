import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Calls the pay API and opens the Stripe checkout URL in the browser.
/// [amount] is the deposit fee in dollars. [bidId] is optional and sent as metadata.
Future<void> startPayment({
  required double amount,
  String? bidId,
  String? receiverId,
}) async {
  print("🚀 startPayment called");
  final body = <String, dynamic>{'amount': amount};
  if (bidId != null) body['bid_id'] = bidId;
  if (receiverId != null && receiverId.trim().isNotEmpty) {
    body['receiver_id'] = receiverId.trim();
  }

  print("📡 sending request...");
  final response = await http.post(
    Uri.parse('http://192.168.0.213:4000/api/pay'),
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
