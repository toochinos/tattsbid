import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_schema.dart';
import '../utils/supabase_list.dart';
import '../utils/user_type_utils.dart';
import '../models/artist_directory_entry.dart';
import '../models/user_profile.dart';
import 'tattoo_request_service.dart';

/// Customers cannot change profile [country] while they still own tattoo requests.
class ProfileCountryChangeBlockedException implements Exception {
  const ProfileCountryChangeBlockedException();

  @override
  String toString() => 'ProfileCountryChangeBlockedException';
}

/// Non-empty [displayName] cannot be changed after it is set (case-insensitive match allowed).
class DisplayNameImmutableException implements Exception {
  const DisplayNameImmutableException();

  @override
  String toString() => 'DisplayNameImmutableException';
}

/// Another profile already uses this display name (case-insensitive).
class DisplayNameTakenException implements Exception {
  const DisplayNameTakenException();

  @override
  String toString() => 'DisplayNameTakenException';
}

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
        country: data?[SupabaseProfiles.country] as String?,
        city: data?[SupabaseProfiles.city] as String?,
        suburb: data?[SupabaseProfiles.suburb] as String?,
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

  /// Auth metadata (`username` / `full_name`), then [profiles] display name, then email.
  static Future<String> resolveLiveDisplayName() async {
    final user = _client.auth.currentUser;
    if (user == null) return 'User';

    final metaUser = user.userMetadata?['username'] as String?;
    final metaName = user.userMetadata?['full_name'] as String?;
    for (final s in [metaUser, metaName]) {
      if (s != null && s.trim().isNotEmpty) return s.trim();
    }

    final profile = await getCurrentProfile();
    final fromProfile = profile?.displayNameOrEmail.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;

    return 'User';
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
      for (final m in mapListFrom(res)) {
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

  /// Canonical user types for labels: `tattoo_artist`, `customer`, or null.
  static Future<Map<String, String?>> getCanonicalUserTypesByUserIds(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return {};
    final unique = userIds.toSet().toList();
    final map = <String, String?>{for (final id in unique) id: null};
    try {
      final res = await _client
          .from(SupabaseProfiles.table)
          .select('${SupabaseProfiles.id}, ${SupabaseProfiles.userType}')
          .inFilter(SupabaseProfiles.id, unique);
      for (final m in mapListFrom(res)) {
        final id = m[SupabaseProfiles.id] as String?;
        if (id == null) continue;
        map[id] = canonicalUserType(m[SupabaseProfiles.userType] as String?);
      }
    } catch (_) {}
    return map;
  }

  /// Escapes `%` / `_` for safe use inside PostgREST `ilike` patterns.
  static String _escapeIlike(String raw) {
    return raw
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  static String _trimmedDisplayNameField(dynamic v) {
    if (v == null) return '';
    if (v is String) return v.trim();
    return v.toString().trim();
  }

  /// Writes [profiles.display_name] into Auth `user_metadata` so the Supabase
  /// Dashboard (Authentication → Users → Display name) stays in sync.
  static Future<void> _syncAuthUserMetadataDisplayName(
    Map<String, dynamic> profileRow,
  ) async {
    final dnVal = profileRow[SupabaseProfiles.displayName];
    final dnStr =
        dnVal is String ? dnVal.trim() : _trimmedDisplayNameField(dnVal);
    if (dnStr.isEmpty) return;
    if (_client.auth.currentSession == null) return;

    final meta = Map<String, dynamic>.from(
      _client.auth.currentUser?.userMetadata ?? const <String, dynamic>{},
    );
    meta['full_name'] = dnStr;
    meta['name'] = dnStr;

    await _client.auth.updateUser(UserAttributes(data: meta));
  }

  static Future<bool> _isDisplayNameTakenByOther(
    String candidate,
    String excludeUserId,
  ) async {
    final t = candidate.trim();
    if (t.isEmpty) return false;
    final pattern = _escapeIlike(t);
    final rows = await _client
        .from(SupabaseProfiles.table)
        .select(SupabaseProfiles.id)
        .neq(SupabaseProfiles.id, excludeUserId)
        .filter(SupabaseProfiles.displayName, 'ilike', pattern)
        .limit(1);
    return mapListFrom(rows).isNotEmpty;
  }

  /// PostgREST `or(...)` clause: match text against name, location line, city, suburb, or country (not bio).
  static String _directoryTextSearchOrClause(String escapedPattern) {
    final p = '%$escapedPattern%';
    return '${SupabaseProfiles.displayName}.ilike.$p,'
        '${SupabaseProfiles.location}.ilike.$p,'
        '${SupabaseProfiles.city}.ilike.$p,'
        '${SupabaseProfiles.suburb}.ilike.$p,'
        '${SupabaseProfiles.country}.ilike.$p';
  }

  /// Tattoo artists for the directory with optional Supabase filters.
  ///
  /// - [textSearch]: matches `display_name`, `location`, `city`, `suburb`, or `country` (OR).
  /// - [locationFilter]: matches `location` (e.g. "Near me" using the user's saved area).
  /// - When **both** are set: text matches the OR above **AND** `location ILIKE locationFilter`.
  ///
  /// Optional `rating` on [profiles] is read when present.
  static Future<List<ArtistDirectoryEntry>> fetchArtistsForDirectory({
    String? textSearch,
    String? locationFilter,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to browse artists');
    }
    final t = _escapeIlike(textSearch?.trim() ?? '');
    final loc = _escapeIlike(locationFilter?.trim() ?? '');

    try {
      var query = _client
          .from(SupabaseProfiles.table)
          .select()
          .eq(SupabaseProfiles.userType, 'tattoo_artist');

      if (t.isNotEmpty && loc.isNotEmpty) {
        query = query
            .or(_directoryTextSearchOrClause(t))
            .filter(SupabaseProfiles.location, 'ilike', '%$loc%');
      } else if (t.isNotEmpty) {
        query = query.or(_directoryTextSearchOrClause(t));
      } else if (loc.isNotEmpty) {
        query = query.filter(SupabaseProfiles.location, 'ilike', '%$loc%');
      }

      final res = await query;
      final out = <ArtistDirectoryEntry>[];
      for (final m in mapListFrom(res)) {
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

  /// Loads all tattoo artists (no text / location filter).
  static Future<List<ArtistDirectoryEntry>> fetchTattooArtistsForDirectory() =>
      fetchArtistsForDirectory();

  /// Location-aware profile search within a selected country.
  ///
  /// Filters by [selectedCountry], matches [search] against city OR suburb
  /// using case-insensitive partial search, and orders by
  /// `last_location_update` ascending.
  static Future<List<Map<String, dynamic>>> searchProfilesByLocation({
    required String selectedCountry,
    required String search,
  }) async {
    final country =
        selectedCountry.trim().isEmpty ? 'Indonesia' : selectedCountry.trim();
    final q = search.trim();

    var query = _client
        .from(SupabaseProfiles.table)
        .select()
        .eq(SupabaseProfiles.country, country);

    if (q.isNotEmpty) {
      query = query.or(
        '${SupabaseProfiles.city}.ilike.%$q%,${SupabaseProfiles.suburb}.ilike.%$q%',
      );
    }

    final res = await query.order(
      SupabaseProfiles.lastLocationUpdate,
      ascending: true,
    );
    return mapListFrom(res);
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
        country: data[SupabaseProfiles.country] as String?,
        city: data[SupabaseProfiles.city] as String?,
        suburb: data[SupabaseProfiles.suburb] as String?,
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
    String? country,
    String? city,
    String? suburb,
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
          .select()
          .eq(SupabaseProfiles.id, user.id)
          .maybeSingle();
    } catch (_) {
      // Profiles table may not exist; use only passed values.
    }

    final existingMap =
        existing is Map ? existing as Map<String, dynamic> : null;
    final existingDnRaw = existingMap?[SupabaseProfiles.displayName];
    final prevTrim = _trimmedDisplayNameField(existingDnRaw);

    if (displayName != null) {
      final reqTrim = displayName.trim();
      if (prevTrim.isNotEmpty) {
        if (reqTrim.isEmpty ||
            reqTrim.toLowerCase() != prevTrim.toLowerCase()) {
          throw const DisplayNameImmutableException();
        }
        data[SupabaseProfiles.displayName] = existingDnRaw;
      } else if (reqTrim.isNotEmpty) {
        if (await _isDisplayNameTakenByOther(reqTrim, user.id)) {
          throw const DisplayNameTakenException();
        }
        data[SupabaseProfiles.displayName] = reqTrim;
      } else {
        data[SupabaseProfiles.displayName] = existingDnRaw;
      }
    } else {
      data[SupabaseProfiles.displayName] = existingDnRaw;
    }
    data[SupabaseProfiles.avatarUrl] =
        avatarUrl ?? existingMap?[SupabaseProfiles.avatarUrl];
    data[SupabaseProfiles.location] =
        location ?? existingMap?[SupabaseProfiles.location];
    data[SupabaseProfiles.country] =
        country ?? existingMap?[SupabaseProfiles.country];
    data[SupabaseProfiles.city] = city ?? existingMap?[SupabaseProfiles.city];
    data[SupabaseProfiles.suburb] =
        suburb ?? existingMap?[SupabaseProfiles.suburb];
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
    final effectiveUserType = data[SupabaseProfiles.userType] as String?;

    final hasLocationUpdateInput =
        country != null || city != null || suburb != null;
    if (hasLocationUpdateInput) {
      data[SupabaseProfiles.lastLocationUpdate] =
          DateTime.now().toIso8601String();
    }

    if (country != null) {
      final next = country.trim();
      final prevRaw = existingMap?[SupabaseProfiles.country] as String?;
      final prev = prevRaw?.trim() ?? '';
      final nextNorm = next.isEmpty ? '' : next.toLowerCase();
      final prevNorm = prev.isEmpty ? '' : prev.toLowerCase();
      if (nextNorm != prevNorm && effectiveUserType == 'customer') {
        final hasPosts =
            await TattooRequestService.currentUserHasAnyOwnedRequest();
        if (hasPosts) {
          throw const ProfileCountryChangeBlockedException();
        }
      }
    }

    try {
      await _client
          .from(SupabaseProfiles.table)
          .upsert(data, onConflict: SupabaseProfiles.id);
      await _syncAuthUserMetadataDisplayName(data);
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      final dup = e.code == '23505' ||
          msg.contains('duplicate key') ||
          msg.contains('unique constraint') ||
          msg.contains('profiles_display_name_lower_unique');
      if (dup) {
        throw const DisplayNameTakenException();
      }
      rethrow;
    }
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
