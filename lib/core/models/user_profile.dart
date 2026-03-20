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
  });

  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String? location;
  final String? bio;
  final String? userType;

  String get displayNameOrEmail =>
      displayName?.trim().isNotEmpty == true ? displayName! : email;
}
