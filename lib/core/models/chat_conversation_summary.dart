/// One row in the Message inbox (partner + last activity).
///
/// Only threads where the **customer** sent the **first** message to the
/// artist appear in the inbox; [inboxTitle] is that partner’s display name.
class ChatConversationSummary {
  const ChatConversationSummary({
    required this.partnerId,
    required this.lastMessagePreview,
    required this.lastMessageAt,
    required this.inboxTitle,
    required this.awaitingMyReply,
  });

  final String partnerId;
  final String lastMessagePreview;
  final DateTime lastMessageAt;

  /// Shown in the inbox row (may be a role label until the rule above is met).
  final String inboxTitle;

  /// True when the latest message in the thread is from the other person (you
  /// haven’t replied yet). Used for bold styling in the inbox.
  final bool awaitingMyReply;

  /// Alias for inbox list / app bar when opening from row.
  String get title => inboxTitle;
}
