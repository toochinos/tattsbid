import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_schema.dart';
import '../utils/supabase_list.dart';
import '../models/bid.dart';

/// Tattoo artists cannot bid when profile country does not match the request’s country.
enum BidCountryBlockedKind {
  requestCountryMissing,
  profileCountryMissing,
  mismatch,
}

class BidCountryBlockedException implements Exception {
  BidCountryBlockedException(
    this.kind, {
    this.requestCountry,
    this.profileCountry,
  });

  final BidCountryBlockedKind kind;
  final String? requestCountry;
  final String? profileCountry;

  @override
  String toString() => 'BidCountryBlockedException($kind)';
}

/// Fetches bids on tattoo requests. Only tattoo artists can place bids.
class BidService {
  BidService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static bool _sameCountry(String? a, String? b) {
    final x = a?.trim().toLowerCase();
    final y = b?.trim().toLowerCase();
    if (x == null || x.isEmpty || y == null || y.isEmpty) return false;
    return x == y;
  }

  /// Whether the signed-in user’s profile has `user_type == tattoo_artist`.
  /// Matches the check in [placeBid] so UI can show the Bid button reliably.
  static Future<bool> isCurrentUserTattooArtist() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final profile = await _client
        .from(SupabaseProfiles.table)
        .select(SupabaseProfiles.userType)
        .eq(SupabaseProfiles.id, user.id)
        .maybeSingle();
    final userType = profile?[SupabaseProfiles.userType] as String?;
    return userType?.trim() == 'tattoo_artist';
  }

  /// Places a bid on a tattoo request. Only tattoo artists can place bids.
  /// [TattooRequest.country] must match the artist’s profile [SupabaseProfiles.country].
  static Future<void> placeBid({
    required String requestId,
    required double bidAmount,
  }) async {
    final user = _client.auth.currentUser;
    // Debug: verify auth user at bid time.
    debugPrint('currentUser: $user');
    if (user == null) throw StateError('User must be authenticated');
    if (bidAmount < 0) throw ArgumentError('Amount must be non-negative');

    // Customers cannot place bids.
    final profile = await _client
        .from(SupabaseProfiles.table)
        .select(
          '${SupabaseProfiles.userType}, ${SupabaseProfiles.country}',
        )
        .eq(SupabaseProfiles.id, user.id)
        .maybeSingle();
    final userType = profile?[SupabaseProfiles.userType] as String?;
    if (userType != 'tattoo_artist') {
      throw StateError(
        userType == 'customer'
            ? 'Customers cannot place bids'
            : 'Only tattoo artists can place bids',
      );
    }

    final profileCountry =
        (profile?[SupabaseProfiles.country] as String?)?.trim();

    final reqRow = await _client
        .from(SupabaseTattooRequests.table)
        .select(
          '${SupabaseTattooRequests.status}, ${SupabaseTattooRequests.country}',
        )
        .eq(SupabaseTattooRequests.id, requestId)
        .maybeSingle();
    final requestStatus =
        reqRow?[SupabaseTattooRequests.status] as String? ?? 'open';
    if (requestStatus != 'open') {
      throw StateError(
        requestStatus == 'completed'
            ? 'Bidding is closed — this request has been completed.'
            : 'Bidding is closed for this request.',
      );
    }

    final requestCountry =
        (reqRow?[SupabaseTattooRequests.country] as String?)?.trim();
    if (requestCountry == null || requestCountry.isEmpty) {
      throw BidCountryBlockedException(
        BidCountryBlockedKind.requestCountryMissing,
        requestCountry: requestCountry,
        profileCountry: profileCountry,
      );
    }
    if (profileCountry == null || profileCountry.isEmpty) {
      throw BidCountryBlockedException(
        BidCountryBlockedKind.profileCountryMissing,
        requestCountry: requestCountry,
        profileCountry: profileCountry,
      );
    }
    if (!_sameCountry(requestCountry, profileCountry)) {
      throw BidCountryBlockedException(
        BidCountryBlockedKind.mismatch,
        requestCountry: requestCountry,
        profileCountry: profileCountry,
      );
    }

    await Supabase.instance.client.from('bids').insert({
      'request_id': requestId,
      'bidder_id': Supabase.instance.client.auth.currentUser!.id,
      'amount': bidAmount,
    });
  }

  static Future<Map<String, String>> _fetchDisplayNames(
      List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final res = await _client
        .from(SupabaseProfiles.table)
        .select('${SupabaseProfiles.id}, ${SupabaseProfiles.displayName}')
        .inFilter(SupabaseProfiles.id, userIds);
    final map = <String, String>{};
    for (final m in mapListFrom(res)) {
      final id = m[SupabaseProfiles.id] as String?;
      final name = m[SupabaseProfiles.displayName] as String?;
      if (id != null && name != null && name.trim().isNotEmpty) {
        map[id] = name;
      }
    }
    return map;
  }

  /// Fetches bids for a tattoo request, ordered by amount (lowest first).
  static Future<List<Bid>> fetchBidsForRequest(String requestId) async {
    final res = await _client
        .from(SupabaseBids.table)
        .select()
        .eq('request_id', requestId)
        .order(SupabaseBids.amount);

    final rows = mapListFrom(res);
    final bidderIds = rows
        .map((r) => r[SupabaseBids.bidderId] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final names = await _fetchDisplayNames(bidderIds);

    return rows.map((m) {
      final bidderId = m[SupabaseBids.bidderId] as String?;
      return Bid.fromJson(
        m,
        bidderName: bidderId != null ? names[bidderId] : null,
      );
    }).toList();
  }
}
