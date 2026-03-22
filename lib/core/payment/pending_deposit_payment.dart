/// Holds the tattoo [requestId] while the customer completes Stripe deposit checkout
/// in an external browser. [CheckoutSuccessPage] reads this to mark the request paid
/// and record contact unlock in Supabase.
class PendingDepositPayment {
  PendingDepositPayment._();

  static String? requestId;

  /// Winning artist (bidder) — used with [requestId] for `record_contact_unlock`.
  static String? artistUserId;

  /// 10% deposit in dollars — stored in [contact_unlocks.deposit_amount].
  static double? depositAmount;

  static void clear() {
    requestId = null;
    artistUserId = null;
    depositAmount = null;
  }
}
