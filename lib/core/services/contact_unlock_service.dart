import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_schema.dart';

/// Persists and checks Stripe deposit unlock rows ([SupabaseContactUnlocks.table]).
class ContactUnlockService {
  ContactUnlockService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// True when a **`paid`** row exists for this customer, artist, and request.
  ///
  /// Same logic as your `checkIfUnlocked(userId, artistId, requestId)` snippet,
  /// using [SupabaseContactUnlocks] column names and enforcing `status == paid`.
  static Future<bool> checkIfUnlocked({
    required String userId,
    required String artistId,
    required String requestId,
  }) async {
    if (userId.trim().isEmpty ||
        artistId.trim().isEmpty ||
        requestId.trim().isEmpty) {
      return false;
    }
    final row = await _client
        .from(SupabaseContactUnlocks.table)
        .select(SupabaseContactUnlocks.id)
        .eq(SupabaseContactUnlocks.userId, userId.trim())
        .eq(SupabaseContactUnlocks.artistId, artistId.trim())
        .eq(SupabaseContactUnlocks.requestId, requestId.trim())
        .eq(SupabaseContactUnlocks.status, SupabaseContactUnlocks.statusPaid)
        .maybeSingle();
    return row != null;
  }

  /// True if the **signed-in** user has a paid unlock for this request + artist.
  static Future<bool> hasPaidUnlock({
    required String requestId,
    required String artistId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    return checkIfUnlocked(
      userId: user.id,
      artistId: artistId,
      requestId: requestId,
    );
  }

  /// Called after successful Stripe deposit; validates owner + winning bid via RPC.
  static Future<void> recordUnlockAfterSuccessfulPayment({
    required String requestId,
    required String artistId,
    double? depositAmount,
  }) async {
    if (artistId.trim().isEmpty) {
      throw ArgumentError('artistId required for contact unlock');
    }
    await _client.rpc<void>(
      'record_contact_unlock',
      params: <String, dynamic>{
        'p_request_id': requestId,
        'p_artist_id': artistId,
        'p_deposit_amount': depositAmount,
      },
    );
  }
}
