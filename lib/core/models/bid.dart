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
    this.bidderAvatarUrl,
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
  final String? bidderAvatarUrl;
  final bool? isWinner;

  /// From [SupabaseBids.paymentStatus]: `unpaid` | `paid` (set by backend after Stripe).
  final String paymentStatus;

  factory Bid.fromJson(
    Map<String, dynamic> json, {
    String? bidderName,
    String? bidderAvatarUrl,
  }) {
    String? name = bidderName;
    String? avatar = bidderAvatarUrl;
    if (name == null || avatar == null) {
      final fromProfiles = json['profiles'] as Map<String, dynamic>?;
      if (name == null) {
        final dn = fromProfiles?['display_name'] as String?;
        name = dn?.trim().isEmpty == true ? null : dn?.trim();
      }
      if (avatar == null) {
        final av = fromProfiles?['avatar_url'] as String?;
        avatar = av?.trim().isEmpty == true ? null : av?.trim();
      }
    }
    return Bid(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      bidderId: json['bidder_id'] as String?,
      artistId: json['artist_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      bidderName: name,
      bidderAvatarUrl: avatar,
      isWinner: json['is_winner'] as bool?,
      paymentStatus:
          (json['payment_status'] as String?)?.trim().isEmpty == false
              ? (json['payment_status'] as String).trim()
              : 'unpaid',
    );
  }
}
