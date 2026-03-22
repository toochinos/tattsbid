/// A direct message between sender and receiver.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime createdAt;

  /// Set when the receiver has read the message (server column [read_at]).
  final DateTime? readAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final createdAtStr = json['created_at'] as String?;
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      content: json['message'] as String? ?? json['content'] as String? ?? '',
      createdAt: createdAtStr != null
          ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
          : DateTime.now(),
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
    );
  }
}
