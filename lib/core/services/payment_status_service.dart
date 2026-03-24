import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_schema.dart';
import '../../screens/public_artist_profile_page.dart';

/// Reads [bids.payment_status] for a request and navigates when paid.
class PaymentStatusService {
  PaymentStatusService._();

  static DateTime? _lastContactNavigationAt;

  /// [startPayment] returns as soon as Stripe opens in the browser — not when payment completes.
  /// Call this **after** `await startPayment(...)` so polling runs once the user can return to the app.
  ///
  /// Waits until the app has left the foreground and comes back (typical when switching from
  /// Safari back to the app), then calls [checkPaymentStatus]. If that lifecycle never fires
  /// (e.g. simulator quirks), falls back after [fallbackDelay].
  static Future<void> checkPaymentStatusAfterCheckoutLaunched(
    BuildContext context,
    String requestId, {
    Duration fallbackDelay = const Duration(seconds: 45),
  }) async {
    final trimmed = requestId.trim();
    if (trimmed.isEmpty) return;

    await Future.any<void>([
      _waitUntilResumedAfterBackground(),
      Future<void>.delayed(fallbackDelay),
    ]);
    if (!context.mounted) return;
    await checkPaymentStatus(context, trimmed);
  }

  static Future<void> _waitUntilResumedAfterBackground() {
    final completer = Completer<void>();
    late final _ResumeAfterBackgroundObserver observer;

    void complete() {
      if (!completer.isCompleted) {
        WidgetsBinding.instance.removeObserver(observer);
        completer.complete();
      }
    }

    observer = _ResumeAfterBackgroundObserver(onReady: complete);
    WidgetsBinding.instance.addObserver(observer);
    return completer.future;
  }

  /// Winning artist for [requestId] when their bid has [payment_status] `paid`.
  static Future<String?> _artistUserIdForPaidWinningBid(String requestId) async {
    final client = Supabase.instance.client;
    final req = await client
        .from(SupabaseTattooRequests.table)
        .select(SupabaseTattooRequests.winningBidId)
        .eq(SupabaseTattooRequests.id, requestId)
        .maybeSingle();
    final winBidId =
        req?[SupabaseTattooRequests.winningBidId] as String?;
    if (winBidId != null && winBidId.isNotEmpty) {
      final bid = await client
          .from(SupabaseBids.table)
          .select()
          .eq(SupabaseBids.id, winBidId)
          .maybeSingle();
      if (bid != null &&
          (bid[SupabaseBids.paymentStatus] as String?)?.trim() == 'paid') {
        final b = bid[SupabaseBids.bidderId] as String?;
        if (b != null && b.isNotEmpty) return b;
      }
    }
    final rows = await client
        .from(SupabaseBids.table)
        .select()
        .eq(SupabaseBids.requestId, requestId)
        .eq(SupabaseBids.paymentStatus, 'paid');
    for (final raw in rows as List<dynamic>) {
      final m = raw as Map<String, dynamic>;
      final b = m[SupabaseBids.bidderId] as String?;
      if (b != null && b.isNotEmpty) return b;
    }
    return null;
  }

  /// Polls Supabase (max 5 × 2s) until the bid for [requestId] is paid, then opens
  /// [PublicArtistProfilePage] for the winning artist.
  ///
  /// Uses `.single()` on `request_id` when exactly one bid exists; if multiple bids exist,
  /// falls back to scanning rows for `payment_status == paid`.
  static Future<void> checkPaymentStatus(
    BuildContext context,
    String requestId,
  ) async {
    final trimmed = requestId.trim();
    if (trimmed.isEmpty) return;

    for (var i = 0; i < 5; i++) {
      if (!context.mounted) return;

      Map<String, dynamic>? row;
      try {
        row = await Supabase.instance.client
            .from(SupabaseBids.table)
            .select()
            .eq(SupabaseBids.requestId, trimmed)
            .single();
      } on PostgrestException {
        final rows = await Supabase.instance.client
            .from(SupabaseBids.table)
            .select()
            .eq(SupabaseBids.requestId, trimmed);
        final list = rows as List<dynamic>;
        for (final r in list) {
          final m = r as Map<String, dynamic>;
          if (m[SupabaseBids.paymentStatus] == 'paid') {
            row = m;
            break;
          }
        }
      }

      if (row != null && row[SupabaseBids.paymentStatus] == 'paid') {
        if (!context.mounted) return;
        final artistUserId = await _artistUserIdForPaidWinningBid(trimmed);
        if (artistUserId == null || artistUserId.isEmpty) return;
        if (!context.mounted) return;
        final now = DateTime.now();
        if (_lastContactNavigationAt != null &&
            now.difference(_lastContactNavigationAt!) <
                const Duration(seconds: 3)) {
          return;
        }
        _lastContactNavigationAt = now;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => PublicArtistProfilePage(
              userId: artistUserId,
              fromArtistsDirectory: false,
            ),
          ),
        );
        return;
      }

      if (i < 4) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }
}

class _ResumeAfterBackgroundObserver with WidgetsBindingObserver {
  _ResumeAfterBackgroundObserver({required this.onReady}) {
    // Stripe may already have taken focus before this observer is added.
    final s = WidgetsBinding.instance.lifecycleState;
    if (s != null && s != AppLifecycleState.resumed) {
      _sawBackground = true;
    }
  }

  final VoidCallback onReady;
  bool _sawBackground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _sawBackground = true;
    }
    if (state == AppLifecycleState.resumed && _sawBackground) {
      // Avoid running before the current frame finishes (route stack stable).
      WidgetsBinding.instance.addPostFrameCallback((_) => onReady());
    }
  }
}
