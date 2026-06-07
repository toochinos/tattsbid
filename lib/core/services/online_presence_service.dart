import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../config/supabase_schema.dart';
import '../utils/supabase_list.dart';

/// Updates user's online presence in [online_users].
class OnlinePresenceService {
  OnlinePresenceService._();

  static const String table = 'online_users';
  static const String userId = 'user_id';
  static const String username = 'username';
  static const String userType = 'user_type';
  static const String lastSeen = 'last_seen';

  /// JS: `const ONLINE_THRESHOLD = 60 * 1000; // 60 seconds`
  static const int onlineThresholdMs = 60 * 1000;
  static const Duration onlineWindow = Duration(seconds: 60);
  static const Duration activeTodayWindow = Duration(hours: 24);

  /// JS: `Date.now() - user.lastSeen < ONLINE_THRESHOLD`
  static bool isOnline(DateTime lastSeen) {
    final seenUtc = lastSeen.toUtc();
    return DateTime.now().toUtc().difference(seenUtc).inMilliseconds <
        onlineThresholdMs;
  }

  /// True when [lastSeen] is after `now() - [window]` (UTC).
  static bool isWithinWindow(DateTime lastSeen, Duration window) {
    if (window == onlineWindow) return isOnline(lastSeen);
    final seenUtc = lastSeen.toUtc();
    final cutoff = DateTime.now().toUtc().subtract(window);
    return seenUtc.isAfter(cutoff);
  }

  /// JS:
  /// ```js
  /// const onlineUsers = users.filter(
  ///   user => Date.now() - user.lastSeen < ONLINE_THRESHOLD
  /// );
  /// ```
  static List<Map<String, dynamic>> filterOnlineUsers(
    List<Map<String, dynamic>> users,
  ) {
    return users.where((user) {
      final seen = parseLastSeen(user[lastSeen]);
      return seen != null && isOnline(seen);
    }).toList();
  }

  /// JS:
  /// ```js
  /// const uniqueOnlineUsers = [...new Map(
  ///   onlineUsers.map(u => [u.userId, u])
  /// ).values()];
  /// ```
  ///
  /// One row per [userId]. If duplicates exist, keeps the row with the latest
  /// [lastSeen] (Map last-wins when timestamps tie or are missing).
  static List<Map<String, dynamic>> uniqueByUserId(
    List<Map<String, dynamic>> users,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final user in users) {
      final id = user[userId]?.toString();
      if (id == null || id.isEmpty) continue;

      final existing = byId[id];
      if (existing == null) {
        byId[id] = user;
        continue;
      }

      final existingSeen = parseLastSeen(existing[lastSeen]);
      final newSeen = parseLastSeen(user[lastSeen]);
      if (newSeen != null &&
          (existingSeen == null || !newSeen.isBefore(existingSeen))) {
        byId[id] = user;
      }
    }
    return byId.values.toList();
  }

  /// Filter by 60s window, then dedupe by [userId].
  static List<Map<String, dynamic>> uniqueOnlineUsers(
    List<Map<String, dynamic>> users,
  ) {
    return uniqueByUserId(filterOnlineUsers(users));
  }

  /// JS: `const onlineCount = uniqueOnlineUsers.length;`
  static int countOnlineFromRows(List<Map<String, dynamic>> rows) {
    return uniqueOnlineUsers(rows).length;
  }

  static DateTime? parseLastSeen(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  static int countRowsWithinWindow(
    List<Map<String, dynamic>> rows,
    Duration window,
  ) {
    return rows.where((row) {
      final seen = parseLastSeen(row[lastSeen]);
      return seen != null && isWithinWindow(seen, window);
    }).length;
  }

  /// Heartbeat / activity — JS equivalent: `user.lastSeen = Date.now()`.
  ///
  /// Persists to [online_users.last_seen] in Supabase (not in-memory only).
  static Future<void> touchLastSeen() => updatePresence();

  /// Upserts [online_users] and sets [last_seen] to now (UTC).
  ///
  /// JS: `user.lastSeen = Date.now()` then save to DB.
  /// Server trigger may overwrite [last_seen] with DB UTC time.
  static Future<void> updatePresence() async {
    if (!isSupabaseReady()) {
      debugPrint('OnlinePresenceService: skipped — Supabase not ready');
      return;
    }
    if (readSupabaseSessionIfReady() == null) {
      debugPrint('OnlinePresenceService: skipped — no auth session');
      return;
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      debugPrint('OnlinePresenceService: skipped — currentUser is null');
      return;
    }

    debugPrint(
      'OnlinePresenceService: update start user_id=${user.id} '
      'table=$table project=$kSupabaseUrl',
    );

    String? usernameValue;
    String? userTypeValue;
    try {
      final profileRes = await client
          .from(SupabaseProfiles.table)
          .select(
            '${SupabaseProfiles.displayName}, ${SupabaseProfiles.userType}',
          )
          .eq(SupabaseProfiles.id, user.id)
          .maybeSingle();

      if (profileRes != null) {
        final row = Map<String, dynamic>.from(profileRes);
        final rawName = row[SupabaseProfiles.displayName] as String?;
        if (rawName != null && rawName.trim().isNotEmpty) {
          usernameValue = rawName.trim();
        }
        final rawType = row[SupabaseProfiles.userType] as String?;
        if (rawType != null && rawType.trim().isNotEmpty) {
          userTypeValue = rawType.trim();
        }
      }
    } catch (e, stack) {
      debugPrint('OnlinePresenceService: profile read failed: $e');
      debugPrint('$stack');
    }

    // user.lastSeen = Date.now()  (UTC ISO for Supabase)
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final payload = {
      userId: user.id,
      username: usernameValue ?? '',
      userType: userTypeValue ?? '',
      lastSeen: nowUtc,
    };

    try {
      final response = await client
          .from(table)
          .upsert(payload, onConflict: userId)
          .select('$userId, $lastSeen');

      final rows = mapListFrom(response);
      if (rows.isEmpty) {
        debugPrint(
          'OnlinePresenceService: upsert returned no rows — '
          'check RLS on $table for user_id=${user.id}',
        );
        return;
      }

      final row = rows.first;
      debugPrint(
        'OnlinePresenceService: upsert ok user_id=${row[userId]} '
        'last_seen=${row[lastSeen]} response=$rows',
      );
    } on PostgrestException catch (e, stack) {
      debugPrint(
        'OnlinePresenceService: PostgrestException code=${e.code} '
        'message=${e.message} details=${e.details}',
      );
      debugPrint('$stack');
    } catch (e, stack) {
      debugPrint('OnlinePresenceService: updatePresence failed: $e');
      debugPrint('$stack');
    }
  }

  /// Removes [userId] (or current user) from [online_users].
  static Future<void> clearPresence({String? forUserId}) async {
    if (!isSupabaseReady()) return;

    final client = Supabase.instance.client;
    final id = forUserId ?? client.auth.currentUser?.id;
    if (id == null) {
      debugPrint('OnlinePresenceService: clearPresence skipped — no user id');
      return;
    }

    try {
      await client.from(table).delete().eq(userId, id);
      debugPrint('OnlinePresenceService: cleared presence user_id=$id');
    } on PostgrestException catch (e, stack) {
      debugPrint(
        'OnlinePresenceService: clearPresence PostgrestException '
        'code=${e.code} message=${e.message}',
      );
      debugPrint('$stack');
    } catch (e, stack) {
      debugPrint('OnlinePresenceService: clearPresence failed: $e');
      debugPrint('$stack');
    }
  }

  static Future<void> pruneStalePresence() async {
    if (!isSupabaseReady()) return;
    try {
      await Supabase.instance.client.rpc('prune_stale_online_users');
      debugPrint('OnlinePresenceService: pruned stale online_users rows');
    } catch (e) {
      debugPrint(
        'OnlinePresenceService: prune_stale_online_users failed '
        '(apply migration 20260611120000): $e',
      );
    }
  }

  /// Rows from [online_users] with [lastSeen] after `now() - [within]`.
  static Future<List<Map<String, dynamic>>> fetchOnlineUsers({
    Duration within = onlineWindow,
  }) async {
    if (!isSupabaseReady()) return [];

    final cutoff = DateTime.now().toUtc().subtract(within).toIso8601String();

    final rows = await Supabase.instance.client
        .from(table)
        .select('$userId, $lastSeen')
        .gt(lastSeen, cutoff);

    final list = mapListFrom(rows);
    debugPrint(
      'OnlinePresenceService: online_users last_seen > $cutoff '
      '→ ${list.length} row(s)',
    );
    return list;
  }

  /// All rows (for debugging).
  static Future<List<Map<String, dynamic>>> fetchOnlineUserRows() async {
    if (!isSupabaseReady()) return [];

    final rows =
        await Supabase.instance.client.from(table).select('$userId, $lastSeen');

    final list = mapListFrom(rows);
    debugPrint(
      'OnlinePresenceService: select online_users ($userId) → ${list.length} row(s)',
    );
    return list;
  }

  /// Dashboard online count — **never** use raw `count(*)` or RPC `online_users` as-is.
  ///
  /// JS:
  /// ```js
  /// const ONLINE_THRESHOLD = 60 * 1000;
  /// const onlineCount = users.filter(
  ///   user => Date.now() - user.lastSeen < ONLINE_THRESHOLD
  /// ).length;
  /// setOnlineUsers(onlineCount);
  /// ```
  static Future<int> computeOnlineCount() async {
    if (!isSupabaseReady()) return 0;

    try {
      final result = await Supabase.instance.client.rpc('count_online_users');
      final count = _parseCount(result);
      debugPrint(
        'OnlinePresenceService: computeOnlineCount=$count (RPC, 60s window)',
      );
      return count;
    } catch (e) {
      debugPrint('OnlinePresenceService: count_online_users RPC failed: $e');
    }

    await pruneStalePresence();
    final users = await fetchOnlineUserRows();
    final onlineCount = countOnlineFromRows(users);
    debugPrint(
      'OnlinePresenceService: computeOnlineCount=$onlineCount '
      '(client filter: Date.now()-lastSeen < ONLINE_THRESHOLD)',
    );
    return onlineCount;
  }

  /// Count online users (60s window). Never unfiltered `count(*)`.
  ///
  /// SQL: `where last_seen > now() - interval '60 seconds'`
  static Future<int> countOnlineUsers({Duration within = onlineWindow}) async {
    if (!isSupabaseReady()) return 0;

    if (within == onlineWindow) {
      return computeOnlineCount();
    }

    final rows = await fetchOnlineUsers(within: within);
    return uniqueByUserId(rows).length;
  }

  /// Count: `last_seen > now() - 24 hours`.
  static Future<int> countActiveUsersToday() async {
    if (!isSupabaseReady()) return 0;

    try {
      final result =
          await Supabase.instance.client.rpc('count_active_users_today');
      final count = _parseCount(result);
      debugPrint(
        'OnlinePresenceService: count_active_users_today RPC=$count',
      );
      return count;
    } catch (e) {
      debugPrint(
        'OnlinePresenceService: count_active_users_today RPC failed: $e',
      );
    }

    final rows = await fetchOnlineUsers(within: activeTodayWindow);
    return rows.length;
  }

  static int _parseCount(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }
}
