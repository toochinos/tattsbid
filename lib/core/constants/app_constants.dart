/// App-wide constants. Add API base URLs, feature flags, etc. when backend is added.
class AppConstants {
  AppConstants._();

  static const String appName = 'SaaS App';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.0.213:4000',
  );

  // bids
  static Uri get bidsUrl => Uri.parse('$apiBaseUrl/api/bids');

  // pay
  static Uri get payUrl => Uri.parse('$apiBaseUrl/api/pay');

  /// Deposit fee as a fraction of the winning bid (e.g. 0.10 = 10%).
  static const double platformFeeRate = 0.10;

  /// Deposit fee percent for UI (e.g. "Deposit fee 10%: …").
  static const int platformFeePercent = 10;

  /// Stripe publishable key (safe for client-side use).
  static const String stripePublishableKey =
      'pk_live_51T67gd0XexFQlFkM7JHrSVxLNgBYcDmWMcmw4quGNBn1jnSkYqveDG3JgE5mpHjdlOYWLJQstY95JMoK0y2av5Jx00cDIdlzLg';

  /// Stripe price IDs. Create prices in Stripe Dashboard (AUD) and replace these.
  static const String stripePricePro = 'price_pro_monthly'; // 99¢ AUD
  static const String stripePriceProMax = 'price_pro_max_monthly'; // $1.00 AUD

  /// Direct Stripe Checkout link for Pro (99¢) subscription.
  static const String stripeProCheckoutUrl =
      'https://buy.stripe.com/14A14fdFp307fOT6Hb6EU01';

  /// Direct Stripe Checkout link for Pro Max subscription.
  static const String stripeProMaxCheckoutUrl =
      'https://buy.stripe.com/dRmeV5eJt8krauz5D76EU00';
}
