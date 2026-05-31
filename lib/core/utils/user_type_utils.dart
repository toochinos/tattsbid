import '../models/user_profile.dart';

/// Maps DB / legacy values to canonical user type strings.
String? canonicalUserType(String? raw) {
  if (raw == null) return null;
  final t = raw.trim().toLowerCase();
  if (t.isEmpty) return null;
  if (t == 'tattoo_artist' || t == 'tattoo artist' || t == 'artist') {
    return 'tattoo_artist';
  }
  if (t == 'customer' || t == 'client') return 'customer';
  return null;
}

/// Prefer [userType]; fall back to [role] (`artist` / `customer` in profiles).
String? resolveProfileUserType({String? userType, String? role}) {
  return canonicalUserType(userType) ?? canonicalUserType(role);
}

/// Explore bid cards (not artist promos).
bool isCustomerBidPost(String? posterUserType) {
  return resolveProfileUserType(userType: posterUserType) != 'tattoo_artist';
}

/// True when the profile has a saved tattoo artist or customer role.
bool profileHasSetAccountType(UserProfile? profile) {
  if (profile == null) return false;
  final c = canonicalUserType(profile.userType);
  return c == 'tattoo_artist' || c == 'customer';
}
