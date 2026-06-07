import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/supabase_config.dart';
import 'online_presence_service.dart';

/// Keeps [online_users] fresh while the user is logged in and the app is foregrounded.
class OnlineHeartbeatService {
  OnlineHeartbeatService._();

  static const Duration interval = Duration(seconds: 30);
  static const Duration _startRetryInterval = Duration(seconds: 5);

  static Timer? _timer;
  static Timer? _startRetryTimer;
  static int _tickCount = 0;
  static bool _periodicRunning = false;

  /// Starts periodic heartbeats (immediate tick + every [interval]).
  static void start() {
    _cancelStartRetry();
    if (!_canRun()) {
      debugPrint(
        'OnlineHeartbeatService: start deferred — '
        'supabaseReady=${isSupabaseReady()} '
        'hasSession=${readSupabaseSessionIfReady() != null}',
      );
      _scheduleStartRetry();
      return;
    }
    _startPeriodic();
  }

  static void stop() {
    _cancelStartRetry();
    if (_periodicRunning || _timer != null) {
      debugPrint('OnlineHeartbeatService: stopped');
    }
    _timer?.cancel();
    _timer = null;
    _periodicRunning = false;
    _tickCount = 0;
  }

  /// Stops heartbeats and removes this user from [online_users].
  static Future<void> goOffline() async {
    final userId = readSupabaseSessionIfReady()?.user.id;
    stop();
    if (userId != null) {
      await OnlinePresenceService.clearPresence(forUserId: userId);
    }
  }

  static bool get isRunning => _periodicRunning && _timer != null;

  /// Heartbeat tick — updates `online_users.last_seen` (like `Date.now()`).
  static Future<void> tickNow() async {
    if (!_canRun()) {
      debugPrint(
        'OnlineHeartbeatService: tick skipped — '
        'supabaseReady=${isSupabaseReady()} '
        'hasSession=${readSupabaseSessionIfReady() != null}',
      );
      return;
    }

    final userId = readSupabaseSessionIfReady()?.user.id;
    debugPrint('OnlineHeartbeatService: tick fired user_id=$userId');
    await OnlinePresenceService.touchLastSeen();
  }

  static bool _canRun() {
    return isSupabaseReady() && readSupabaseSessionIfReady() != null;
  }

  static void _startPeriodic() {
    _timer?.cancel();
    _periodicRunning = true;
    _tickCount = 0;

    final userId = readSupabaseSessionIfReady()?.user.id;
    debugPrint(
      'OnlineHeartbeatService: started user_id=$userId '
      'interval=${interval.inSeconds}s',
    );

    unawaited(tickNow());
    _timer = Timer.periodic(interval, (_) {
      _tickCount++;
      debugPrint('OnlineHeartbeatService: periodic #$_tickCount');
      unawaited(tickNow());
    });
  }

  static void _scheduleStartRetry() {
    if (_startRetryTimer != null) return;
    _startRetryTimer = Timer.periodic(_startRetryInterval, (_) {
      if (!_canRun()) {
        debugPrint('OnlineHeartbeatService: start retry — still not ready');
        return;
      }
      debugPrint('OnlineHeartbeatService: start retry succeeded');
      _cancelStartRetry();
      _startPeriodic();
    });
  }

  static void _cancelStartRetry() {
    _startRetryTimer?.cancel();
    _startRetryTimer = null;
  }
}
