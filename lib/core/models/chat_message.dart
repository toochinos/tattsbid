/// A direct message between sender and receiver.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime createdAt;

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
    );
  }
}
