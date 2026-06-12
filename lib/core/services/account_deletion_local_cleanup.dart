import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'online_heartbeat_service.dart';
import 'online_presence_service.dart';
import 'video_cache_manager.dart';

/// Clears on-device caches and session data after server-side account deletion.
class AccountDeletionLocalCleanup {
  AccountDeletionLocalCleanup._();

  /// Best-effort wipe of local media caches, preferences, and Supabase session.
  static Future<void> clearUserLocalData() async {
    await VideoCacheManager.clearAll();
    try {
      await DefaultCacheManager().emptyCache();
    } catch (e, st) {
      debugPrint('AccountDeletionLocalCleanup: image cache: $e\n$st');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('AccountDeletionLocalCleanup: preferences: $e');
    }

    OnlineHeartbeatService.stop();

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await OnlinePresenceService.clearPresence(forUserId: userId);
      } catch (e) {
        debugPrint('AccountDeletionLocalCleanup: presence: $e');
      }
    }

    try {
      await client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('AccountDeletionLocalCleanup: local signOut: $e');
    }
  }
}
