/// App-wide constants. Add API base URLs, feature flags, etc. when backend is added.
class AppConstants {
  AppConstants._();

  static const String appName = 'SaaS App';

  /// Default HTTP API origin (no `/api/...` suffix). Override with
  /// `--dart-define=API_URL=...` when building or running.
  ///
  /// Avoid `http://127.0.0.1:4040` (ngrok **inspector**, not your app) and avoid
  /// `localhost` / `127.0.0.1` on **device** builds — use the same public HTTPS URL
  /// as `server.js` (`API_URL` / `PUBLIC_BASE_URL`), e.g. ngrok tunnel → port **4000**.
  static const String baseUrl =
      'https://telegraphic-banausic-kathey.ngrok-free.dev';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: baseUrl,
  );

  // bids
  static Uri get bidsUrl => Uri.parse('$apiBaseUrl/api/bids');

  /// Node `server.js` route: `POST /create-payment`.
  static const String payApiPath = '/create-payment';

  static Uri get payUrl => Uri.parse('$apiBaseUrl$payApiPath');

  /// Node `server.js`: `POST /verify-payment` — records [contact_unlocks] from Stripe session.
  static const String verifyPaymentPath = '/verify-payment';

  static Uri get verifyPaymentUrl => Uri.parse('$apiBaseUrl$verifyPaymentPath');

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
