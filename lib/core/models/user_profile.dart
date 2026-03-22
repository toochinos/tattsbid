/// User profile data from auth and optional profiles table.
/// userType: 'tattoo_artist' or 'customer'
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.location,
    this.bio,
    this.userType,
    this.contactEmail,
    this.mobile,
    this.portfolioUrls = const [],
  });

  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String? location;
  final String? bio;
  final String? userType;
  final String? contactEmail;
  final String? mobile;

  /// Public portfolio images (tattoo artists only; max 10 in app).
  final List<String> portfolioUrls;

  String get displayNameOrEmail =>
      displayName?.trim().isNotEmpty == true ? displayName! : email;
}
