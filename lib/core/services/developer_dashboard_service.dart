import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/developer_dashboard.dart';
import 'online_presence_service.dart';

/// Loads developer dashboard stats via `get_dashboard_stats()` RPC.
class DeveloperDashboardService {
  DeveloperDashboardService._();

  static const String _rpcName = 'get_dashboard_stats';

  /// `last_seen > now() - 60 seconds` (never unfiltered count(*)).
  static Future<int> fetchOnlineUsersCount() async {
    if (!isSupabaseReady()) return 0;
    return OnlinePresenceService.computeOnlineCount();
  }

  /// JS: `updateDashboard({ onlineUsers: onlineCount })`
  ///
  /// Merges filtered presence counts into [current]. Fetches counts when omitted.
  static Future<DeveloperDashboard> updateDashboard({
    DeveloperDashboard? current,
    int? onlineUsers,
    int? activeUsersToday,
  }) async {
    if (!isSupabaseReady()) {
      return current ?? DeveloperDashboard.empty;
    }

    final base = current ?? DeveloperDashboard.empty;
    final onlineCount =
        onlineUsers ?? await OnlinePresenceService.computeOnlineCount();
    final activeCount =
        activeUsersToday ?? await OnlinePresenceService.countActiveUsersToday();

    debugPrint(
      'DeveloperDashboardService updateDashboard: '
      'onlineUsers=$onlineCount activeUsersToday=$activeCount',
    );

    return base.copyWith(
      onlineUsers: onlineCount,
      activeUsersToday: activeCount,
    );
  }

  /// Loads dashboard stats. Online / active counts use filtered presence only.
  static Future<DeveloperDashboard> fetchDashboard() async {
    if (!isSupabaseReady()) {
      debugPrint('DeveloperDashboardService: Supabase not ready');
      return DeveloperDashboard.empty;
    }

    final client = Supabase.instance.client;
    final rpcResult = await client.rpc(_rpcName);
    debugPrint('DeveloperDashboardService raw RPC response: $rpcResult');

    final base = DeveloperDashboard.fromRpcJson(_asStatsMap(rpcResult));

    final allRows = await OnlinePresenceService.fetchOnlineUserRows();
    for (final row in allRows) {
      final seen = OnlinePresenceService.parseLastSeen(
        row[OnlinePresenceService.lastSeen],
      );
      final online = seen != null &&
          OnlinePresenceService.isWithinWindow(
            seen,
            OnlinePresenceService.onlineWindow,
          );
      debugPrint(
        'DeveloperDashboardService row user_id=${row[OnlinePresenceService.userId]} '
        'last_seen=${row[OnlinePresenceService.lastSeen]} counted_online=$online',
      );
    }

    return updateDashboard(current: base);
  }

  static Map<String, dynamic> _asStatsMap(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    if (result is String && result.isNotEmpty) {
      try {
        final decoded = jsonDecode(result);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (e) {
        debugPrint('DeveloperDashboardService: JSON decode failed: $e');
      }
    }
    debugPrint(
      'DeveloperDashboardService: unexpected RPC type ${result.runtimeType}',
    );
    return const {};
  }
}
