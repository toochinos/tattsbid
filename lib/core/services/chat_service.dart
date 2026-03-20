import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_schema.dart';
import '../models/chat_message.dart';

/// Fetches and sends direct messages.
class ChatService {
  ChatService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Fetches messages for a conversation between current user and [receiverId].
  /// Uses sender_id/receiver_id filter so both users see the thread.
  static Future<List<ChatMessage>> fetchMessages(String receiverId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to load messages');
    }

    final userId = user.id;
    final res = await _client
        .from(SupabaseChatMessages.table)
        .select()
        .or(
          'and(sender_id.eq.$userId,receiver_id.eq.$receiverId),and(sender_id.eq.$receiverId,receiver_id.eq.$userId)',
        )
        .order(SupabaseChatMessages.createdAt, ascending: true);

    return (res as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sends a direct message to [receiverId].
  static Future<void> sendMessage(String content, String receiverId) async {
    final text = content.trim();
    if (text.isEmpty) return;

    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to send messages');
    }

    await _client.from(SupabaseChatMessages.table).insert({
      'message': text,
      SupabaseChatMessages.content: text,
      SupabaseChatMessages.senderId: user.id,
      SupabaseChatMessages.receiverId: receiverId,
    });
  }
}
