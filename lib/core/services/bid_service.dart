import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_schema.dart';
import '../utils/supabase_list.dart';
import '../utils/user_type_utils.dart';
import '../models/bid.dart';

/// Fetches and places bids on tattoo requests.
class BidService {
  BidService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Whether the signed-in user’s profile has `user_type == tattoo_artist`.
  static Future<bool> isCurrentUserTattooArtist() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final profile = await _client
        .from(SupabaseProfiles.table)
        .select(SupabaseProfiles.userType)
        .eq(SupabaseProfiles.id, user.id)
        .maybeSingle();
    final userType = profile?[SupabaseProfiles.userType] as String?;
    return canonicalUserType(userType) == 'tattoo_artist';
  }

  static Future<String?> _profileUserType(String userId) async {
    final row = await _client
        .from(SupabaseProfiles.table)
        .select(SupabaseProfiles.userType)
        .eq(SupabaseProfiles.id, userId)
        .maybeSingle();
    return canonicalUserType(row?[SupabaseProfiles.userType] as String?);
  }

  /// Places a bid: artists on customer jobs, customers on artist promos.
  static Future<void> placeBid({
    required String requestId,
    required double bidAmount,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User must be authenticated');
    if (bidAmount < 0) throw ArgumentError('Amount must be non-negative');

    final reqRow = await _client
        .from(SupabaseTattooRequests.table)
        .select(
          '${SupabaseTattooRequests.status}, '
          '${SupabaseTattooRequests.userId}',
        )
        .eq(SupabaseTattooRequests.id, requestId)
        .maybeSingle();
    if (reqRow == null) {
      throw StateError('Request not found.');
    }
    final requestStatus =
        reqRow[SupabaseTattooRequests.status] as String? ?? 'open';
    if (requestStatus != 'open') {
      throw StateError(
        requestStatus == 'completed'
            ? 'Bidding is closed — this request has been completed.'
            : 'Bidding is closed for this request.',
      );
    }

    final posterId = (reqRow[SupabaseTattooRequests.userId] as String?)?.trim();
    if (posterId != null && posterId == user.id) {
      throw StateError('You cannot bid on your own post.');
    }

    final bidderType = await _profileUserType(user.id);
    final posterType = posterId != null && posterId.isNotEmpty
        ? await _profileUserType(posterId)
        : null;

    if (posterType == 'tattoo_artist') {
      if (bidderType == 'tattoo_artist') {
        throw StateError('Tattoo artists cannot bid on artist promos.');
      }
      if (bidderType != 'customer') {
        throw StateError('Only customers can bid on artist promos.');
      }
    } else {
      if (bidderType != 'tattoo_artist') {
        throw StateError('Only tattoo artists can bid on customer requests.');
      }
    }

    await _client.from(SupabaseBids.table).insert({
      SupabaseBids.requestId: requestId,
      SupabaseBids.bidderId: user.id,
      SupabaseBids.amount: bidAmount,
    });
  }

  static Future<Map<String, ({String? name, String? avatarUrl})>>
      _fetchBidderProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final res = await _client
        .from(SupabaseProfiles.table)
        .select(
          '${SupabaseProfiles.id}, ${SupabaseProfiles.displayName}, '
          '${SupabaseProfiles.avatarUrl}',
        )
        .inFilter(SupabaseProfiles.id, userIds);
    final map = <String, ({String? name, String? avatarUrl})>{};
    for (final m in mapListFrom(res)) {
      final id = m[SupabaseProfiles.id] as String?;
      if (id == null) continue;
      final name = m[SupabaseProfiles.displayName] as String?;
      final avatar = m[SupabaseProfiles.avatarUrl] as String?;
      map[id] = (
        name: name?.trim().isEmpty == true ? null : name?.trim(),
        avatarUrl: avatar?.trim().isEmpty == true ? null : avatar?.trim(),
      );
    }
    return map;
  }

  /// Fetches bids for a tattoo request, ordered by amount (lowest first).
  static Future<List<Bid>> fetchBidsForRequest(String requestId) async {
    final res = await _client
        .from(SupabaseBids.table)
        .select()
        .eq(SupabaseBids.requestId, requestId)
        .order(SupabaseBids.amount);

    final rows = mapListFrom(res);
    final bidderIds = rows
        .map((r) => r[SupabaseBids.bidderId] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final profiles = await _fetchBidderProfiles(bidderIds);

    return rows.map((m) {
      final bidderId = m[SupabaseBids.bidderId] as String?;
      final profile = bidderId != null ? profiles[bidderId] : null;
      return Bid.fromJson(
        m,
        bidderName: profile?.name,
        bidderAvatarUrl: profile?.avatarUrl,
      );
    }).toList();
  }
}
