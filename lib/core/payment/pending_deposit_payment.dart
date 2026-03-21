/// Holds the tattoo [requestId] while the customer completes Stripe deposit checkout
/// in an external browser. [CheckoutSuccessPage] reads this to mark the request paid.
class PendingDepositPayment {
  PendingDepositPayment._();

  static String? requestId;

  static void clear() {
    requestId = null;
  }
}
