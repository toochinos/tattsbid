import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_schema.dart';
import '../models/user_profile.dart';

/// Fetches and updates user profile. Uses auth user + optional profiles table.
class ProfileService {
  ProfileService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Gets current user's profile. Falls back to auth user if no profile row.
  static Future<UserProfile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final res = await _client
          .from(SupabaseProfiles.table)
          .select(SupabaseProfiles.selectAll)
          .eq(SupabaseProfiles.id, user.id)
          .maybeSingle();

      final data = res;
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        displayName: data?[SupabaseProfiles.displayName] as String?,
        avatarUrl: data?[SupabaseProfiles.avatarUrl] as String?,
        location: data?[SupabaseProfiles.location] as String?,
        bio: data?[SupabaseProfiles.bio] as String?,
        userType: data?[SupabaseProfiles.userType] as String?,
      );
    } catch (_) {
      // Profiles table may not exist; use auth user only.
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['full_name'] as String?,
        avatarUrl: user.userMetadata?['avatar_url'] as String?,
      );
    }
  }

  /// Updates profile. Creates row if missing.
  /// Pass null for a field to leave it unchanged (merge with existing).
  static Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? location,
    String? bio,
    String? userType,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final Map<String, dynamic> data = {
      SupabaseProfiles.id: user.id,
      SupabaseProfiles.updatedAt: DateTime.now().toIso8601String(),
    };

    // Merge with existing profile so we don't overwrite fields not being updated
    dynamic existing;
    try {
      existing = await _client
          .from(SupabaseProfiles.table)
          .select(SupabaseProfiles.selectAll)
          .eq(SupabaseProfiles.id, user.id)
          .maybeSingle();
    } catch (_) {
      // Profiles table may not exist; use only passed values.
    }

    final existingMap =
        existing is Map ? existing as Map<String, dynamic> : null;
    data[SupabaseProfiles.displayName] =
        displayName ?? existingMap?[SupabaseProfiles.displayName];
    data[SupabaseProfiles.avatarUrl] =
        avatarUrl ?? existingMap?[SupabaseProfiles.avatarUrl];
    data[SupabaseProfiles.location] =
        location ?? existingMap?[SupabaseProfiles.location];
    data[SupabaseProfiles.bio] = bio ?? existingMap?[SupabaseProfiles.bio];
    // Once set to tattoo_artist or customer, user type cannot be changed.
    final existingUserType = existingMap?[SupabaseProfiles.userType] as String?;
    data[SupabaseProfiles.userType] =
        (existingUserType == 'tattoo_artist' || existingUserType == 'customer')
            ? existingUserType
            : (userType ?? existingUserType);

    await _client
        .from(SupabaseProfiles.table)
        .upsert(data, onConflict: SupabaseProfiles.id);
  }

  /// Uploads a profile picture and updates the profile avatar_url.
  /// File path format: avatars/{userId}/avatar.{ext}
  static Future<String?> uploadAvatar(File file) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final ext = file.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
      throw ArgumentError('Invalid image format. Use jpg, png, webp, or gif.');
    }

    final path = '${user.id}/avatar.$ext';

    await _client.storage.from('avatars').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    final baseUrl = _client.storage.from('avatars').getPublicUrl(path);
    // Add cache-busting param so the new image displays (same path = cached otherwise).
    final url = '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    await updateProfile(avatarUrl: url);
    return url;
  }
}
