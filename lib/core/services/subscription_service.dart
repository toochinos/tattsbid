import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles Stripe subscription: create checkout, confirm, and refresh status.
class SubscriptionService {
  SubscriptionService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Creates a Stripe Checkout session and returns the hosted checkout URL.
  /// Pass [priceId] for the Stripe price (e.g. price_xxx for Pro or Pro Max).
  /// For web, pass [successBaseUrl] (e.g. 'https://yourapp.com/#/checkout/success').
  static Future<String> createCheckoutSession({
    String? priceId,
    String? successBaseUrl,
    String? cancelBaseUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User must be signed in to subscribe');
    }
    final body = <String, dynamic>{
      'userId': user.id,
      'email': user.email,
    };
    if (priceId != null) body['price_id'] = priceId;
    if (successBaseUrl != null) body['success_base_url'] = successBaseUrl;
    if (cancelBaseUrl != null) body['cancel_base_url'] = cancelBaseUrl;
    final res = await _client.functions.invoke(
      'create-checkout-session',
      body: body,
    );
    if (res.status != 200) {
      throw Exception(
          res.data?['error'] ?? 'Failed to create checkout session');
    }
    final url = res.data?['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('No checkout URL returned');
    }
    return url;
  }

  /// Confirms checkout using session_id from Stripe redirect. Returns status.
  static Future<SubscriptionStatus> confirmCheckout(String sessionId) async {
    final res = await _client.functions.invoke(
      'confirm-checkout',
      body: {'session_id': sessionId},
    );
    if (res.status != 200) {
      throw Exception(res.data?['error'] ?? 'Failed to confirm checkout');
    }
    final data = res.data as Map<String, dynamic>?;
    return SubscriptionStatus(
      subscribed: data?['subscribed'] as bool? ?? false,
      status: data?['status'] as String? ?? 'none',
    );
  }

  /// Fetches current subscription status from Stripe.
  static Future<SubscriptionStatus> getStatus() async {
    final res = await _client.functions.invoke('get-subscription-status');
    if (res.status != 200) {
      throw Exception(
          res.data?['error'] ?? 'Failed to get subscription status');
    }
    final data = res.data as Map<String, dynamic>?;
    return SubscriptionStatus(
      subscribed: data?['subscribed'] as bool? ?? false,
      status: data?['status'] as String? ?? 'none',
    );
  }
}

class SubscriptionStatus {
  const SubscriptionStatus({
    required this.subscribed,
    required this.status,
  });

  final bool subscribed;
  final String status;
}
