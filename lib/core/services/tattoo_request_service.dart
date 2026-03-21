import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_schema.dart';
import '../models/tattoo_request.dart';

/// Creates and manages tattoo requests (photo + description + starting bid).
class TattooRequestService {
  TattooRequestService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Fetches display names and locations for user IDs from profiles.
  static Future<Map<String, ({String? name, String? location})>> _fetchProfiles(
      List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final res = await _client
        .from(SupabaseProfiles.table)
        .select(
            '${SupabaseProfiles.id}, ${SupabaseProfiles.displayName}, ${SupabaseProfiles.location}')
        .inFilter(SupabaseProfiles.id, userIds);
    final map = <String, ({String? name, String? location})>{};
    for (final row in res as List<dynamic>) {
      final m = row as Map<String, dynamic>;
      final id = m[SupabaseProfiles.id] as String?;
      final name = m[SupabaseProfiles.displayName] as String?;
      final location = m[SupabaseProfiles.location] as String?;
      if (id != null) {
        map[id] = (name: name, location: location);
      }
    }
    return map;
  }

  /// Fetches bid counts per request_id for the given request IDs.
  static Future<Map<String, int>> _fetchBidCounts(
      List<String> requestIds) async {
    if (requestIds.isEmpty) return {};
    final res = await _client
        .from(SupabaseBids.table)
        .select(SupabaseBids.requestId)
        .inFilter(SupabaseBids.requestId, requestIds);
    final counts = <String, int>{};
    for (final row in res as List<dynamic>) {
      final m = row as Map<String, dynamic>;
      final rid = m[SupabaseBids.requestId] as String?;
      if (rid != null) {
        counts[rid] = (counts[rid] ?? 0) + 1;
      }
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
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User must be authenticated');

    if (startingBid < 0) {
      throw ArgumentError('Starting bid must be non-negative.');
    }

    final data = {
      SupabaseTattooRequests.userId: user.id,
      SupabaseTattooRequests.imageUrl: imageUrl,
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

    final list = res as List;
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

    final list = res as List;
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

    return _withDisplayNames(res as List<dynamic>);
  }

  /// Fetches tattoo requests for the Explore page.
  static Future<List<TattooRequest>> fetchOpenRequests() async {
    final res = await _client
        .from(SupabaseTattooRequests.table)
        .select()
        .order(SupabaseTattooRequests.createdAt, ascending: false);

    return _withDisplayNames(res as List<dynamic>);
  }

  static Future<List<TattooRequest>> _withDisplayNames(
      List<dynamic> rows) async {
    final requests = rows as List<Map<String, dynamic>>;
    final userIds = requests
        .map((r) => r[SupabaseTattooRequests.userId] as String)
        .toSet()
        .toList();
    final requestIds =
        requests.map((r) => r[SupabaseTattooRequests.id] as String).toList();
    final profiles = await _fetchProfiles(userIds);
    final bidCounts = await _fetchBidCounts(requestIds);

    return requests.map((e) {
      final uid = e[SupabaseTattooRequests.userId] as String?;
      final rid = e[SupabaseTattooRequests.id] as String?;
      final profile = uid != null ? profiles[uid] : null;
      final bidCount = rid != null ? (bidCounts[rid] ?? 0) : 0;
      return TattooRequest.fromJson(e,
          customerName: profile?.name,
          customerLocation: profile?.location,
          bidCount: bidCount);
    }).toList();
  }
}
