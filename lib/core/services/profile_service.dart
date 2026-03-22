import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_schema.dart';
import '../models/artist_directory_entry.dart';
import '../models/user_profile.dart';

/// Fetches and updates user profile. Uses auth user + optional profiles table.
class ProfileService {
  ProfileService._();

  /// Max portfolio images per tattoo artist (enforced in app + uploads).
  static const int maxPortfolioImages = 10;

  static SupabaseClient get _client => Supabase.instance.client;

  static List<String> _parsePortfolioUrls(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e?.toString() ?? '')
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    return [];
  }

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
        contactEmail: data?[SupabaseProfiles.contactEmail] as String?,
        mobile: data?[SupabaseProfiles.mobile] as String?,
        portfolioUrls:
            _parsePortfolioUrls(data?[SupabaseProfiles.portfolioUrls]),
      );
    } catch (_) {
      // Profiles table may not exist; use auth user only.
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['full_name'] as String?,
        avatarUrl: user.userMetadata?['avatar_url'] as String?,
        portfolioUrls: const [],
      );
    }
  }

  /// Display names for many user ids (inbox, lists). Missing ids get "User".
  static Future<Map<String, String>> getDisplayNamesByUserIds(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return {};
    final unique = userIds.toSet().toList();
    try {
      final res = await _client
          .from(SupabaseProfiles.table)
          .select('${SupabaseProfiles.id}, ${SupabaseProfiles.displayName}')
          .inFilter(SupabaseProfiles.id, unique);
      final map = <String, String>{};
      for (final row in res as List<dynamic>) {
        final m = row as Map<String, dynamic>;
        final id = m[SupabaseProfiles.id] as String?;
        final dn = m[SupabaseProfiles.displayName] as String?;
        if (id != null) {
          map[id] = (dn != null && dn.trim().isNotEmpty) ? dn.trim() : 'User';
        }
      }
      for (final id in unique) {
        map.putIfAbsent(id, () => 'User');
      }
      return map;
    } catch (_) {
      return {for (final id in unique) id: 'User'};
    }
  }

  /// All tattoo artists for the Artists directory (alphabetical sort is done in app).
  /// Requires RLS to allow authenticated users to read artist profiles.
  ///
  /// Optional `rating` on [profiles] is read when present.
  static Future<List<ArtistDirectoryEntry>>
      fetchTattooArtistsForDirectory() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to browse artists');
    }
    try {
      final res = await _client
          .from(SupabaseProfiles.table)
          .select()
          .eq(SupabaseProfiles.userType, 'tattoo_artist');

      final out = <ArtistDirectoryEntry>[];
      for (final raw in res as List) {
        final m = raw as Map<String, dynamic>;
        try {
          out.add(ArtistDirectoryEntry.fromSupabaseRow(m));
        } catch (_) {
          // Skip malformed rows
        }
      }
      out.sort((a, b) => a.sortKey.compareTo(b.sortKey));
      return out;
    } catch (e) {
      throw Exception('Could not load artists: $e');
    }
  }

  /// Public profile fields for another user (e.g. bid winner). No auth email.
  static Future<UserProfile?> getProfileByUserId(String userId) async {
    if (userId.trim().isEmpty) return null;
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final res = await _client
          .from(SupabaseProfiles.table)
          .select(SupabaseProfiles.selectAll)
          .eq(SupabaseProfiles.id, userId.trim())
          .maybeSingle();

      if (res == null) return null;
      final data = res;
      return UserProfile(
        id: userId.trim(),
        email: '',
        displayName: data[SupabaseProfiles.displayName] as String?,
        avatarUrl: data[SupabaseProfiles.avatarUrl] as String?,
        location: data[SupabaseProfiles.location] as String?,
        bio: data[SupabaseProfiles.bio] as String?,
        userType: data[SupabaseProfiles.userType] as String?,
        contactEmail: data[SupabaseProfiles.contactEmail] as String?,
        mobile: data[SupabaseProfiles.mobile] as String?,
        portfolioUrls:
            _parsePortfolioUrls(data[SupabaseProfiles.portfolioUrls]),
      );
    } catch (_) {
      return null;
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
    String? contactEmail,
    String? mobile,
    List<String>? portfolioUrls,

    /// When true, always apply [userType] (e.g. sign-up or first-time role pick).
    bool forceUserType = false,
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
    data[SupabaseProfiles.contactEmail] =
        contactEmail ?? existingMap?[SupabaseProfiles.contactEmail];
    data[SupabaseProfiles.mobile] =
        mobile ?? existingMap?[SupabaseProfiles.mobile];
    if (portfolioUrls != null) {
      data[SupabaseProfiles.portfolioUrls] = portfolioUrls;
    } else {
      data[SupabaseProfiles.portfolioUrls] =
          existingMap?[SupabaseProfiles.portfolioUrls];
    }
    // Once set to tattoo_artist or customer, user type cannot be changed
    // unless [forceUserType] (sign-up / first completion).
    final existingUserType = existingMap?[SupabaseProfiles.userType] as String?;
    final hasPersistedRole =
        existingUserType == 'tattoo_artist' || existingUserType == 'customer';
    data[SupabaseProfiles.userType] = forceUserType && userType != null
        ? userType
        : hasPersistedRole
            ? existingUserType
            : (userType ?? existingUserType);

    await _client
        .from(SupabaseProfiles.table)
        .upsert(data, onConflict: SupabaseProfiles.id);
  }

  /// Replaces `portfolio_urls` for the current user.
  ///
  /// [userId] must equal the signed-in user’s id (avoids accidental cross-user
  /// writes). Prefer this over raw `.from('profiles').update(...)` so
  /// [updated_at] and merge rules stay aligned with [updateProfile].
  static Future<void> savePortfolio(String userId, List<String> urls) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to save your portfolio.');
    }
    if (user.id != userId) {
      throw ArgumentError('userId must match the signed-in user.');
    }
    await updateProfile(portfolioUrls: urls);
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

  /// Uploads one portfolio image for the current user (tattoo artist). Max
  /// [maxPortfolioImages] total. Uses Supabase Storage bucket **`portfolio`**
  /// with path `{userId}/{timestamp}.{ext}` (RLS: first folder = auth uid).
  static Future<String> uploadPortfolioImage(File file) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to upload portfolio images');
    }

    final ext = file.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
      throw ArgumentError('Invalid image format. Use jpg, png, webp, or gif.');
    }

    final existing = await getCurrentProfile();
    final current = List<String>.from(existing?.portfolioUrls ?? []);
    if (current.length >= maxPortfolioImages) {
      throw StateError(
        'You can upload up to $maxPortfolioImages portfolio images.',
      );
    }

    final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from('portfolio').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: false),
        );

    final baseUrl = _client.storage.from('portfolio').getPublicUrl(path);
    final url = '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    final next = [...current, url];
    await updateProfile(portfolioUrls: next);
    return url;
  }

  /// Uploads multiple portfolio images in order.
  ///
  /// Only uploads as many as fit under [maxPortfolioImages] for the current
  /// profile (unlike a blind `take(10)` on the file list). Returns public URLs
  /// in the same order as [files] (may be shorter than [files]).
  ///
  /// Each upload **already** merges into `portfolio_urls` on the profile. Do not
  /// call [savePortfolio] with only these returned URLs — that would **replace**
  /// the whole list and remove existing images.
  static Future<List<String>> uploadPortfolioImages(List<File> files) async {
    if (files.isEmpty) return [];

    final existing = await getCurrentProfile();
    final currentCount = (existing?.portfolioUrls ?? []).length;
    final remaining = maxPortfolioImages - currentCount;
    if (remaining <= 0) return [];

    final urls = <String>[];
    for (final file in files.take(remaining)) {
      urls.add(await uploadPortfolioImage(file));
    }
    return urls;
  }

  /// Like [uploadPortfolioImages], but checks [userId] matches the signed-in user.
  ///
  /// Profile is still updated incrementally; **do not** follow with
  /// `savePortfolio(userId, urls)` using only [urls] — see [uploadPortfolioImages].
  static Future<List<String>> uploadPortfolio(
    List<File> files,
    String userId,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to upload portfolio images.');
    }
    if (user.id != userId) {
      throw ArgumentError('userId must match the signed-in user.');
    }
    return uploadPortfolioImages(files);
  }

  /// Removes a portfolio image by index and updates the profile.
  static Future<void> removePortfolioImageAt(int index) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final existing = await getCurrentProfile();
    final current = List<String>.from(existing?.portfolioUrls ?? []);
    if (index < 0 || index >= current.length) return;

    current.removeAt(index);
    await updateProfile(portfolioUrls: current);
  }
}
