import 'package:flutter/foundation.dart';

import '../config/supabase_config.dart';
import 'online_presence_service.dart';

/// One-shot presence update; periodic updates use [OnlineHeartbeatService].
class LastSeenService {
  LastSeenService._();

  /// Activity hook — same as JS `user.lastSeen = Date.now()`.
  static Future<void> updateLastSeen() async {
    if (!isSupabaseReady()) return;
    if (readSupabaseSessionIfReady() == null) return;

    try {
      await OnlinePresenceService.touchLastSeen();
      // ignore: avoid_print
      print('Updated last_seen for user');
    } catch (e, stack) {
      debugPrint('LastSeenService: updateLastSeen failed: $e');
      debugPrint('$stack');
    }
  }
}
