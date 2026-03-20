import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_schema.dart';
import '../models/bid.dart';

/// Fetches bids on tattoo requests. Only tattoo artists can place bids.
class BidService {
  BidService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Places a bid on a tattoo request. Only tattoo artists can place bids.
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
        .select(SupabaseProfiles.userType)
        .eq(SupabaseProfiles.id, user.id)
        .maybeSingle();
    final userType = profile?[SupabaseProfiles.userType] as String?;
    if (userType == 'customer') {
      throw StateError('Customers cannot place bids');
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
    for (final row in res as List<dynamic>) {
      final m = row as Map<String, dynamic>;
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

    final rows = res as List;
    final bidderIds = rows
        .map((r) =>
            (r as Map<String, dynamic>)[SupabaseBids.bidderId] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final names = await _fetchDisplayNames(bidderIds);

    return rows.map((e) {
      final m = e as Map<String, dynamic>;
      final bidderId = m[SupabaseBids.bidderId] as String?;
      return Bid.fromJson(
        m,
        bidderName: bidderId != null ? names[bidderId] : null,
      );
    }).toList();
  }
}
