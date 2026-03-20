/// A customer's tattoo request with reference photo, description, and starting bid.
class TattooRequest {
  const TattooRequest({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.startingBid,
    this.description,
    this.status = 'open',
    this.winningBidId,
    required this.createdAt,
    this.updatedAt,
    this.customerName,
    this.customerLocation,
    this.bidCount = 0,
    this.placement,
    this.size,
    this.colourPreference,
    this.artistCreativeFreedom = true,
    this.timeframe,
  });

  final String id;
  final String userId;
  final String imageUrl;
  final String? customerName;
  final String? customerLocation;
  final int bidCount;
  final String? description;
  final String? placement;
  final String? size;
  final String? colourPreference;
  final bool artistCreativeFreedom;
  final String? timeframe;
  final double startingBid;
  final String status;
  final String? winningBidId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory TattooRequest.fromJson(
    Map<String, dynamic> json, {
    String? customerName,
    String? customerLocation,
    int bidCount = 0,
  }) {
    return TattooRequest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      imageUrl: json['image_url'] as String,
      customerName: customerName,
      customerLocation: customerLocation,
      bidCount: bidCount,
      description: json['description'] as String?,
      placement: json['placement'] as String?,
      size: json['size'] as String?,
      colourPreference: json['colour_preference'] as String?,
      artistCreativeFreedom: json['artist_creative_freedom'] as bool? ?? true,
      timeframe: json['timeframe'] as String?,
      startingBid: (json['starting_bid'] as num).toDouble(),
      status: json['status'] as String? ?? 'open',
      winningBidId: json['winning_bid_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}
