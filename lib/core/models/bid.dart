/// A bid on a tattoo request.
class Bid {
  const Bid({
    required this.id,
    required this.requestId,
    this.bidderId,
    this.artistId,
    required this.amount,
    required this.createdAt,
    this.bidderName,
    this.isWinner,
    this.paymentStatus = 'unpaid',
  });

  final String id;
  final String requestId;
  final String? bidderId;
  final String? artistId;
  final double amount;
  final DateTime createdAt;
  final String? bidderName;
  final bool? isWinner;

  /// From [SupabaseBids.paymentStatus]: `unpaid` | `paid` (set by backend after Stripe).
  final String paymentStatus;

  factory Bid.fromJson(Map<String, dynamic> json, {String? bidderName}) {
    String? name = bidderName;
    if (name == null) {
      final fromProfiles = json['profiles'] as Map<String, dynamic>?;
      final dn = fromProfiles?['display_name'] as String?;
      name = dn?.trim().isEmpty == true ? null : dn?.trim();
    }
    return Bid(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      bidderId: json['bidder_id'] as String?,
      artistId: json['artist_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      bidderName: name,
      isWinner: json['is_winner'] as bool?,
      paymentStatus:
          (json['payment_status'] as String?)?.trim().isEmpty == false
              ? (json['payment_status'] as String).trim()
              : 'unpaid',
    );
  }
}
