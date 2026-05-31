import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_schema.dart';
import '../utils/supabase_list.dart';
import '../models/tattoo_request.dart';
import '../utils/user_type_utils.dart';
import 'review_service.dart';

/// Creates and manages tattoo requests (photo + description + starting bid).
class TattooRequestService {
  TattooRequestService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Fetches display names and locations for user IDs from profiles.
  static Future<
          Map<String, ({String? name, String? location, String? userType})>>
      _fetchProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final res = await _client
        .from(SupabaseProfiles.table)
        .select(
          '${SupabaseProfiles.id}, ${SupabaseProfiles.displayName}, '
          '${SupabaseProfiles.location}, ${SupabaseProfiles.userType}',
        )
        .inFilter(SupabaseProfiles.id, userIds);
    final map =
        <String, ({String? name, String? location, String? userType})>{};
    for (final m in mapListFrom(res)) {
      final id = m[SupabaseProfiles.id] as String?;
      final name = m[SupabaseProfiles.displayName] as String?;
      final location = m[SupabaseProfiles.location] as String?;
      final userType =
          canonicalUserType(m[SupabaseProfiles.userType] as String?);
      if (id != null) {
        map[id] = (name: name, location: location, userType: userType);
      }
    }
    return map;
  }

  /// Who counts as “interested” on explore cards.
  static String? _interestedPartyTypeForPoster(String? posterUserType) {
    if (canonicalUserType(posterUserType) == 'tattoo_artist') {
      return 'customer';
    }
    return 'tattoo_artist';
  }

  static bool _bidderCountsForExplore(
    String? bidderType,
    String? wantType,
    String? posterType,
  ) {
    if (bidderType == wantType) return true;
    if (bidderType != null) return false;
    if (wantType == 'tattoo_artist' &&
        canonicalUserType(posterType) != 'tattoo_artist') {
      return true;
    }
    if (wantType == 'customer' &&
        canonicalUserType(posterType) == 'tattoo_artist') {
      return true;
    }
    return false;
  }

  /// Interest count + avatar previews filtered by poster type.
  static Future<Map<String, ({int count, List<String> avatarUrls})>>
      _fetchInterestPreviews(
    List<Map<String, dynamic>> rows,
    Map<String, ({String? name, String? location, String? userType})>
        posterProfiles, {
    int maxAvatars = 3,
  }) async {
    final requestIds =
        rows.map((r) => r[SupabaseTattooRequests.id] as String).toList();
    if (requestIds.isEmpty) return {};

    final posterTypeByRequest = <String, String?>{};
    for (final r in rows) {
      final rid = r[SupabaseTattooRequests.id] as String?;
      final uid = r[SupabaseTattooRequests.userId] as String?;
      if (rid != null) {
        posterTypeByRequest[rid] =
            uid != null ? posterProfiles[uid]?.userType : null;
      }
    }

    final res = await _client
        .from(SupabaseBids.table)
        .select(
          '${SupabaseBids.requestId}, ${SupabaseBids.bidderId}, '
          '${SupabaseBids.createdAt}',
        )
        .inFilter(SupabaseBids.requestId, requestIds)
        .order(SupabaseBids.createdAt, ascending: false);

    final bidsByRequest = <String, List<String>>{};
    for (final m in mapListFrom(res)) {
      final rid = m[SupabaseBids.requestId] as String?;
      final bidder = m[SupabaseBids.bidderId] as String?;
      if (rid == null || bidder == null || bidder.isEmpty) continue;
      bidsByRequest.putIfAbsent(rid, () => []).add(bidder);
    }

    final bidderIds =
        bidsByRequest.values.expand((ids) => ids).toSet().toList();
    if (bidderIds.isEmpty) {
      return {
        for (final id in requestIds) id: (count: 0, avatarUrls: <String>[])
      };
    }

    final profileRes = await _client
        .from(SupabaseProfiles.table)
        .select(
          '${SupabaseProfiles.id}, ${SupabaseProfiles.userType}, '
          '${SupabaseProfiles.avatarUrl}',
        )
        .inFilter(SupabaseProfiles.id, bidderIds);
    final bidderProfiles = <String, ({String? userType, String? avatarUrl})>{};
    for (final m in mapListFrom(profileRes)) {
      final id = m[SupabaseProfiles.id] as String?;
      if (id == null) continue;
      final userType =
          canonicalUserType(m[SupabaseProfiles.userType] as String?);
      final avatar = (m[SupabaseProfiles.avatarUrl] as String?)?.trim();
      bidderProfiles[id] = (
        userType: userType,
        avatarUrl: avatar?.isEmpty == true ? null : avatar,
      );
    }

    final previews = <String, ({int count, List<String> avatarUrls})>{};
    for (final rid in requestIds) {
      final posterType = posterTypeByRequest[rid];
      final wantType = _interestedPartyTypeForPoster(posterType);
      final seen = <String>{};
      var count = 0;
      final avatars = <String>[];
      for (final bidderId in bidsByRequest[rid] ?? const []) {
        final profile = bidderProfiles[bidderId];
        if (!_bidderCountsForExplore(
          profile?.userType,
          wantType,
          posterType,
        )) {
          continue;
        }
        if (!seen.add(bidderId)) continue;
        count++;
        if (avatars.length < maxAvatars) {
          avatars.add(profile?.avatarUrl ?? '');
        }
      }
      previews[rid] = (count: count, avatarUrls: avatars);
    }
    return previews;
  }

  static Future<Map<String, int>> _fetchReviewCounts(
    List<String> artistIds,
  ) async {
    if (artistIds.isEmpty) return {};
    final res = await _client
        .from(SupabaseReviews.table)
        .select(SupabaseReviews.artistId)
        .inFilter(SupabaseReviews.artistId, artistIds);
    final counts = <String, int>{};
    for (final m in mapListFrom(res)) {
      final aid = m[SupabaseReviews.artistId] as String?;
      if (aid == null || aid.isEmpty) continue;
      counts.update(aid, (v) => v + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// Creates a tattoo request. Call after photo is uploaded.
  static Future<TattooRequest> createRequest({
    required String imageUrl,
    String? description,
    String? placement,
    String? size,
    String? colourPreference,
    bool artistCreativeFreedom = true,
    String? timeframe,
    required double startingBid,
    required String country,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User must be authenticated');

    if (startingBid < 0) {
      throw ArgumentError('Starting bid must be non-negative.');
    }

    final trimmedCountry = country.trim();
    if (trimmedCountry.isEmpty) {
      throw ArgumentError('Country is required for new tattoo requests.');
    }

    final data = {
      SupabaseTattooRequests.userId: user.id,
      SupabaseTattooRequests.imageUrl: imageUrl,
      SupabaseTattooRequests.country: trimmedCountry,
      SupabaseTattooRequests.description:
          description?.trim().isEmpty == true ? null : description?.trim(),
      SupabaseTattooRequests.placement:
          placement?.trim().isEmpty == true ? null : placement?.trim(),
      SupabaseTattooRequests.size:
          size?.trim().isEmpty == true ? null : size?.trim(),
      SupabaseTattooRequests.colourPreference:
          colourPreference?.trim().isEmpty == true
              ? null
              : colourPreference?.trim(),
      SupabaseTattooRequests.artistCreativeFreedom: artistCreativeFreedom,
      SupabaseTattooRequests.timeframe:
          timeframe?.trim().isEmpty == true ? null : timeframe?.trim(),
      SupabaseTattooRequests.startingBid: startingBid,
      SupabaseTattooRequests.updatedAt: DateTime.now().toIso8601String(),
    };

    final res = await _client
        .from(SupabaseTattooRequests.table)
        .insert(data)
        .select()
        .single();

    return TattooRequest.fromJson(res);
  }

  /// Whether the signed-in user owns at least one tattoo request (any status).
  static Future<bool> currentUserHasAnyOwnedRequest() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      final res = await _client
          .from(SupabaseTattooRequests.table)
          .select(SupabaseTattooRequests.id)
          .eq(SupabaseTattooRequests.userId, user.id)
          .limit(1);
      return mapListFrom(res).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a tattoo request. Only the owner can delete (enforced by RLS).
  /// Throws if delete did not remove a row (RLS blocked or row not found).
  static Future<void> deleteRequest(String requestId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User must be authenticated');

    final res = await _client
        .from(SupabaseTattooRequests.table)
        .delete()
        .eq(SupabaseTattooRequests.id, requestId)
        .eq(SupabaseTattooRequests.userId, user.id)
        .select();

    final list = mapListFrom(res);
    if (list.isEmpty) {
      throw StateError('Delete failed: row not found or you are not the owner');
    }
  }

  /// Sets the winning bid for a tattoo request (customer/owner only, enforced by RLS).
  static Future<void> setWinningBid({
    required String requestId,
    required String bidId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User must be authenticated');

    await _client
        .from(SupabaseTattooRequests.table)
        .update({
          SupabaseTattooRequests.winningBidId: bidId,
          SupabaseTattooRequests.status: 'in_progress',
          SupabaseTattooRequests.updatedAt: DateTime.now().toIso8601String(),
        })
        .eq(SupabaseTattooRequests.id, requestId)
        .eq(SupabaseTattooRequests.userId, user.id);
  }

  /// Marks a request as completed after the customer finishes the deposit payment.
  /// Owner-only (RLS). Call from [CheckoutSuccessPage] when [PendingDepositPayment.requestId] is set.
  static Future<void> markRequestCompletedAfterPayment({
    required String requestId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User must be authenticated');

    final res = await _client
        .from(SupabaseTattooRequests.table)
        .update({
          SupabaseTattooRequests.status: 'completed',
          SupabaseTattooRequests.updatedAt: DateTime.now().toIso8601String(),
        })
        .eq(SupabaseTattooRequests.id, requestId)
        .eq(SupabaseTattooRequests.userId, user.id)
        .select();

    final list = mapListFrom(res);
    if (list.isEmpty) {
      throw StateError(
        'Could not mark request completed: not found or not owner',
      );
    }
  }

  /// Fetches all tattoo requests, newest first.
  static Future<List<TattooRequest>> fetchAllRequests() async {
    final res = await _client
        .from(SupabaseTattooRequests.table)
        .select()
        .order(SupabaseTattooRequests.createdAt, ascending: false);

    return _withDisplayNames(mapListFrom(res));
  }

  /// Fetches tattoo requests for Explore. When [country] is null or empty,
  /// returns all rows visible under RLS (worldwide feed). Otherwise filters
  /// by [SupabaseTattooRequests.country].
  static Future<List<TattooRequest>> fetchOpenRequests(
      {String? country}) async {
    final c = country?.trim();
    if (c == null || c.isEmpty) {
      final res = await _client
          .from(SupabaseTattooRequests.table)
          .select()
          .order(SupabaseTattooRequests.createdAt, ascending: false);
      return _withDisplayNames(mapListFrom(res));
    }
    final res = await _client
        .from(SupabaseTattooRequests.table)
        .select()
        .eq(SupabaseTattooRequests.country, c)
        .order(SupabaseTattooRequests.createdAt, ascending: false);

    return _withDisplayNames(mapListFrom(res));
  }

  /// Latest row for one request (e.g. after payment — refresh status / winning_bid_id).
  static Future<TattooRequest?> fetchRequestById(String requestId) async {
    if (requestId.trim().isEmpty) return null;
    final res = await _client
        .from(SupabaseTattooRequests.table)
        .select()
        .eq(SupabaseTattooRequests.id, requestId.trim())
        .maybeSingle();
    if (res == null) return null;
    final list = await _withDisplayNames(mapListFrom([res]));
    return list.isEmpty ? null : list.first;
  }

  static Future<List<TattooRequest>> _withDisplayNames(
      List<Map<String, dynamic>> rows) async {
    final requests = rows;
    final userIds = requests
        .map((r) => r[SupabaseTattooRequests.userId] as String)
        .toSet()
        .toList();
    final profiles = await _fetchProfiles(userIds);
    final interest = await _fetchInterestPreviews(rows, profiles);
    final artistIds = profiles.entries
        .where((e) => e.value.userType == 'tattoo_artist')
        .map((e) => e.key)
        .toList();
    final reviewAvgs =
        await ReviewService.fetchDualAveragesForArtistIds(artistIds);
    final reviewCounts = await _fetchReviewCounts(artistIds);

    return requests.map((e) {
      final uid = e[SupabaseTattooRequests.userId] as String?;
      final rid = e[SupabaseTattooRequests.id] as String?;
      final profile = uid != null ? profiles[uid] : null;
      final preview = rid != null ? interest[rid] : null;
      final bidCount = preview?.count ?? 0;
      final avatarUrls = preview?.avatarUrls ?? const <String>[];
      final dual = uid != null ? reviewAvgs[uid] : null;
      final rating =
          dual != null && dual.experienceMean > 0 ? dual.experienceMean : null;
      final reviewCount = uid != null ? (reviewCounts[uid] ?? 0) : 0;
      return TattooRequest.fromJson(
        e,
        customerName: profile?.name,
        customerLocation: profile?.location,
        posterUserType: profile?.userType,
        posterRating: rating,
        posterReviewCount: reviewCount,
        bidCount: bidCount,
        bidderAvatarUrls: avatarUrls,
      );
    }).toList();
  }
}
