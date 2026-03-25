import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_schema.dart';

/// Centralized read/write for one-time user agreement acceptance.
class UserAgreementService {
  UserAgreementService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Returns true when the signed-in user has accepted terms.
  static Future<bool> hasAcceptedTerms() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final row = await _client
          .from(SupabaseProfiles.table)
          .select(SupabaseProfiles.hasAcceptedTerms)
          .eq(SupabaseProfiles.id, user.id)
          .maybeSingle();
      final raw = row?[SupabaseProfiles.hasAcceptedTerms];
      return raw == true;
    } catch (_) {
      return false;
    }
  }

  /// Marks the signed-in user as having accepted terms.
  static Future<void> acceptTerms() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to accept terms.');
    }

    await _client.from(SupabaseProfiles.table).upsert({
      SupabaseProfiles.id: user.id,
      SupabaseProfiles.hasAcceptedTerms: true,
      SupabaseProfiles.updatedAt: DateTime.now().toUtc().toIso8601String(),
    }, onConflict: SupabaseProfiles.id);
  }
}
