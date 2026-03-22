import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_service.dart';

/// Green envelope on the Message tab when any inbox thread is awaiting your reply.
class MessageIndicatorService {
  MessageIndicatorService._();

  static final ValueNotifier<bool> hasUnread = ValueNotifier<bool>(false);

  static RealtimeChannel? _channel;
  static Timer? _pollTimer;

  static void start() {
    _pollTimer?.cancel();
    _channel?.unsubscribe();

    refresh();

    _channel = Supabase.instance.client
        .channel('message_tab_indicator')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) => refresh(),
        )
        .subscribe();

    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
  }

  static void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _channel?.unsubscribe();
    _channel = null;
  }

  static Future<void> refresh() async {
    try {
      final v = await ChatService.hasAnyConversationAwaitingMyReply();
      hasUnread.value = v;
    } catch (_) {
      // Network / schema
    }
  }
}
