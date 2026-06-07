import 'package:flutter/foundation.dart';

/// Stats from Supabase RPC `get_dashboard_stats()` (JSON / jsonb).
///
/// Presence metrics [onlineUsers] and [activeUsersToday] come from
/// `online_users.last_seen` (UTC), not profiles.
class DeveloperDashboard {
  const DeveloperDashboard({
    required this.onlineUsers,
    required this.activeUsersToday,
    required this.totalUsers,
    required this.totalCustomers,
    required this.totalArtists,
    required this.newUsersThisWeek,
    required this.totalTattooRequests,
    this.generatedAt,
  });

  static const empty = DeveloperDashboard(
    onlineUsers: 0,
    activeUsersToday: 0,
    totalUsers: 0,
    totalCustomers: 0,
    totalArtists: 0,
    newUsersThisWeek: 0,
    totalTattooRequests: 0,
  );

  /// `online_users` with last_seen within 60 seconds (UTC).
  final int onlineUsers;

  /// `online_users` with last_seen within 24 hours (UTC).
  final int activeUsersToday;
  final int totalUsers;
  final int totalCustomers;

  /// From JSON key `total_artists`.
  final int totalArtists;
  final int newUsersThisWeek;
  final int totalTattooRequests;
  final DateTime? generatedAt;

  DeveloperDashboard copyWith({
    int? onlineUsers,
    int? activeUsersToday,
    int? totalUsers,
    int? totalCustomers,
    int? totalArtists,
    int? newUsersThisWeek,
    int? totalTattooRequests,
    DateTime? generatedAt,
  }) {
    return DeveloperDashboard(
      onlineUsers: onlineUsers ?? this.onlineUsers,
      activeUsersToday: activeUsersToday ?? this.activeUsersToday,
      totalUsers: totalUsers ?? this.totalUsers,
      totalCustomers: totalCustomers ?? this.totalCustomers,
      totalArtists: totalArtists ?? this.totalArtists,
      newUsersThisWeek: newUsersThisWeek ?? this.newUsersThisWeek,
      totalTattooRequests: totalTattooRequests ?? this.totalTattooRequests,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  factory DeveloperDashboard.fromRpcJson(Map<String, dynamic> json) {
    // Do NOT read json['online_users'] / json['users_online_now'] here.
    // Those may be stale or unfiltered. Service sets onlineUsers via
    // computeOnlineCount() → setOnlineUsers(onlineCount).
    final dashboard = DeveloperDashboard(
      onlineUsers: 0,
      activeUsersToday: 0,
      totalUsers: _intOrZero(json['total_users']),
      totalCustomers: _intOrZero(json['total_customers']),
      totalArtists: _intOrZero(json['total_artists']),
      newUsersThisWeek: _intOrZero(json['new_users_this_week']),
      totalTattooRequests: _intOrZero(json['total_tattoo_requests']),
      generatedAt: _parseDateTime(json['generated_at']),
    );

    debugPrint(
      'DeveloperDashboard parsed totals (online/active filled by service): '
      'totalUsers=${dashboard.totalUsers}',
    );
    debugPrint('DeveloperDashboard raw RPC keys: ${json.keys.toList()}');
    debugPrint('DeveloperDashboard raw RPC json: $json');

    return dashboard;
  }

  static int _intOrZero(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is bool) return value ? 1 : 0;
    if (value is String) {
      final trimmed = value.trim();
      final parsed = int.tryParse(trimmed);
      if (parsed != null) return parsed;
      final asDouble = double.tryParse(trimmed);
      if (asDouble != null) return asDouble.round();
    }
    debugPrint(
      'DeveloperDashboard _intOrZero: unhandled type ${value.runtimeType} value=$value',
    );
    return 0;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
