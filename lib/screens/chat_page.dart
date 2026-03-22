import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_schema.dart';
import '../core/models/chat_conversation_summary.dart';
import '../core/models/chat_message.dart';
import '../core/services/chat_service.dart';
import '../core/services/message_indicator_service.dart';

/// Private 1:1 chat room between a tattoo artist and a customer only.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.initialReceiverId});

  final String? initialReceiverId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  RealtimeChannel? _realtimeChannel;
  final Map<String, String> _displayNames = {};
  String? _receiverId;
  String? _partnerDisplayName;
  String? _receiverEmail;
  String? _receiverMobile;
  List<ChatConversationSummary> _conversations = [];
  bool _loadingConversations = false;
  String? _conversationsError;

  @override
  void initState() {
    super.initState();
    _receiverId = widget.initialReceiverId;
    _subscribeToRealtime();
    if (_receiverId != null) {
      _loadMessages();
    } else {
      setState(() => _loading = false);
      _loadConversations();
    }
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loadingConversations = true;
      _conversationsError = null;
    });
    try {
      final list = await ChatService.fetchConversationSummaries();
      if (!mounted) return;
      setState(() {
        _conversations = list;
        _loadingConversations = false;
      });
      await MessageIndicatorService.refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _conversationsError = e.toString();
        _loadingConversations = false;
      });
    }
  }

  void _openConversation(ChatConversationSummary row) {
    setState(() {
      _receiverId = row.partnerId;
      _partnerDisplayName = row.title;
      _loading = true;
      _messages = [];
      _error = null;
    });
    _loadMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('chat_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) {
            MessageIndicatorService.refresh();
            if (_receiverId != null) {
              _loadMessages();
            } else {
              _loadConversations();
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadMessages() async {
    final receiverId = _receiverId;
    if (receiverId == null) return;

    try {
      final messages = await ChatService.fetchMessages(receiverId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
        _error = null;
      });
      try {
        await ChatService.markConversationRead(receiverId);
        await MessageIndicatorService.refresh();
      } catch (_) {
        // e.g. read_at column not migrated yet
      }
      await _loadReceiverContact(receiverId);
      final title = await ChatService.inboxTitleForPartner(receiverId);
      if (mounted) setState(() => _partnerDisplayName = title);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Standard chat: oldest at top, newest at bottom — pin scroll to the bottom
  /// after layout so new messages stay in view.
  void _scrollToBottom() {
    void jump() {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(max);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      jump();
      // Second frame: [ListView] may not have final extent after first layout.
      WidgetsBinding.instance.addPostFrameCallback((_) => jump());
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final receiverId = _receiverId;
    if (text.isEmpty || _sending || receiverId == null) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      await ChatService.sendMessage(text, receiverId);
      if (!mounted) return;
      await _loadMessages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<String> _getDisplayName(String userId) async {
    if (_displayNames.containsKey(userId)) {
      return _displayNames[userId]!;
    }
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();
      final name = res?['display_name'] as String?;
      final display = name?.trim().isNotEmpty == true ? name! : 'User';
      _displayNames[userId] = display;
      return display;
    } catch (_) {
      return 'User';
    }
  }

  Future<void> _loadReceiverContact(String receiverId) async {
    try {
      final row = await Supabase.instance.client
          .from(SupabaseProfiles.table)
          .select('*')
          .eq(SupabaseProfiles.id, receiverId)
          .maybeSingle();
      if (!mounted) return;
      final data = row is Map<String, dynamic> ? row : <String, dynamic>{};
      final email = (data[SupabaseProfiles.contactEmail] ??
              data['email'] ??
              data['contact_email'])
          ?.toString()
          .trim();
      final mobile = (data[SupabaseProfiles.mobile] ??
              data['phone'] ??
              data['phone_number'])
          ?.toString()
          .trim();
      setState(() {
        _receiverEmail = (email != null && email.isNotEmpty) ? email : null;
        _receiverMobile = (mobile != null && mobile.isNotEmpty) ? mobile : null;
      });
    } catch (_) {
      // Non-fatal: contact fields can be absent depending on schema/RLS.
      if (!mounted) return;
      setState(() {
        _receiverEmail = null;
        _receiverMobile = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _receiverId == null ? 'Message' : (_partnerDisplayName ?? 'Chat')),
        leading: _receiverId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _receiverId = null;
                    _partnerDisplayName = null;
                    _messages = [];
                    _error = null;
                    _receiverEmail = null;
                    _receiverMobile = null;
                  });
                  _loadConversations();
                },
              )
            : null,
      ),
      body: Column(
        children: [
          if (_receiverId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Messages between tattoo artists and customers only. '
                'Only you and this person can see these messages.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
          if (_receiverId != null &&
              (_receiverEmail != null || _receiverMobile != null))
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.35),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (_receiverMobile != null) ...[
                    const SizedBox(height: 6),
                    Text('Mobile: $_receiverMobile'),
                  ],
                  if (_receiverEmail != null) ...[
                    const SizedBox(height: 4),
                    Text('Email: $_receiverEmail'),
                  ],
                ],
              ),
            ),
          Expanded(
            child: _buildMessageList(),
          ),
          if (_receiverId != null) _buildInputBar(),
        ],
      ),
    );
  }

  String _formatConversationTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    return MaterialLocalizations.of(context).formatShortDate(local);
  }

  Widget _buildInbox() {
    if (_loadingConversations && _conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_conversationsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _conversationsError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadConversations,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No conversations yet',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Chats from Explore (customer messages first) and conversations '
                'with an artist after you pay the deposit appear here.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _conversations.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final c = _conversations[index];
          final preview = c.lastMessagePreview.length > 80
              ? '${c.lastMessagePreview.substring(0, 77)}...'
              : c.lastMessagePreview;
          final initial =
              c.title.isNotEmpty ? c.title.substring(0, 1).toUpperCase() : '?';
          final w = c.awaitingMyReply ? FontWeight.w700 : FontWeight.w500;
          return ListTile(
            leading: CircleAvatar(
              child: Text(
                initial,
                style: TextStyle(
                    fontWeight: c.awaitingMyReply ? FontWeight.w800 : null),
              ),
            ),
            title: Text(
              c.title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: w),
            ),
            subtitle: Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: c.awaitingMyReply ? FontWeight.w600 : null,
                  ),
            ),
            trailing: Text(
              _formatConversationTime(c.lastMessageAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    fontWeight: c.awaitingMyReply ? FontWeight.w700 : null,
                  ),
            ),
            onTap: () => _openConversation(c),
          );
        },
      ),
    );
  }

  Widget _buildMessageList() {
    if (_receiverId == null) {
      return _buildInbox();
    }
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _messages.isEmpty) {
      final isTableMissing = _error!.contains('chat_messages') ||
          _error!.contains('PGRST205') ||
          _error!.contains('schema cache');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isTableMissing
                    ? 'Chat setup required. Run the migration in '
                        'supabase/apply_chat_messages.sql in your Supabase '
                        'Dashboard (SQL Editor), then tap Retry.'
                    : _error!,
                style: TextStyle(
                  color: isTableMissing
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadMessages();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No messages yet. Say hello — this conversation is only visible '
            'to you and the other person.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final uid = Supabase.instance.client.auth.currentUser?.id;
    // [fetchMessages] returns oldest → newest; render in that order (standard chat).
    final chronological = List<ChatMessage>.from(_messages);
    final latest = chronological.isNotEmpty ? chronological.last : null;
    final emphasizeLatestIncoming =
        latest != null && uid != null && latest.senderId != uid;
    final latestId = latest?.id;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: chronological.length,
      itemBuilder: (context, index) {
        final msg = chronological[index];
        final boldThis = emphasizeLatestIncoming && msg.id == latestId;
        return _buildMessageBubble(msg, emphasize: boldThis);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, {bool emphasize = false}) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isMe = msg.senderId == currentUserId;
    // Avatar/name shows the sender (who wrote the message).
    final senderId = msg.senderId;

    return FutureBuilder<String>(
      future: _getDisplayName(senderId),
      builder: (context, snapshot) {
        final name = snapshot.data ?? 'User';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe)
                CircleAvatar(
                  radius: 16,
                  child: Text(name.substring(0, 1).toUpperCase()),
                ),
              if (!isMe) const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 2),
                        child: Text(
                          name,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.white,
                        border: isMe
                            ? null
                            : Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.35),
                              ),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                      ),
                      child: Text(
                        msg.content,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight:
                                  emphasize ? FontWeight.w700 : FontWeight.w400,
                            ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        _formatTime(msg.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isMe) const SizedBox(width: 8),
              if (isMe)
                CircleAvatar(
                  radius: 16,
                  child: Text(name.substring(0, 1).toUpperCase()),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Message (private)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _sendMessage,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
