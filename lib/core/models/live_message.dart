/// One row from [live_messages]. [message] is the Supabase/PostgREST string as-is;
/// do not utf8.decode, String.fromCharCodes, or other transforms on read.
class LiveMessage {
  const LiveMessage({
    this.id,
    this.localEchoId,
    this.userId,
    required this.username,
    required this.message,
    required this.createdAt,
  });

  final Object? id;
  final int? localEchoId;
  final String? userId;
  final String username;
  final String message;
  final DateTime createdAt;

  factory LiveMessage.fromRow(Map<String, dynamic> row) {
    final createdRaw = row['created_at'];
    final created = createdRaw is String
        ? (DateTime.tryParse(createdRaw) ?? DateTime.now().toUtc())
        : DateTime.now().toUtc();

    return LiveMessage(
      id: row['id'],
      userId: row['user_id']?.toString(),
      username: row['username'] as String? ?? '',
      message: row['message'] as String,
      createdAt: created,
    );
  }
}
