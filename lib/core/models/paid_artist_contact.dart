/// Artist shown on the Message tab after the customer’s winning bid is paid.
class PaidArtistContact {
  const PaidArtistContact({
    required this.artistUserId,
    required this.requestId,
    required this.bidId,
    required this.displayName,
    this.mobile,
    this.contactEmail,
    this.avatarUrl,
  });

  final String artistUserId;
  final String requestId;
  final String bidId;
  final String displayName;
  final String? mobile;
  final String? contactEmail;
  final String? avatarUrl;
}
