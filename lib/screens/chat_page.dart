import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_schema.dart';
import '../core/models/chat_message.dart';
import '../core/services/chat_service.dart';

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
  String? _receiverEmail;
  String? _receiverMobile;

  @override
  void initState() {
    super.initState();
    _receiverId = widget.initialReceiverId;
    _subscribeToRealtime();
    if (_receiverId != null) {
      _loadMessages();
    } else {
      setState(() => _loading = false);
    }
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
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) => _loadMessages(),
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
      await _loadReceiverContact(receiverId);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
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
        title: const Text('Private chat'),
        leading: _receiverId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _receiverId = null;
                  _messages = [];
                  _error = null;
                  _receiverEmail = null;
                  _receiverMobile = null;
                }),
              )
            : null,
      ),
      body: Column(
        children: [
          if (_receiverId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Private chat between tattoo artists and customers only. '
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
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Artist contact',
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

  Widget _buildMessageList() {
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_receiverId == null) {
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
                'Private chat room',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This is a private space only between tattoo artists and '
                'customers. Open a chat from a profile or after you pay a '
                'winning bid.',
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
            'No messages yet. Say hello — this private chat is only visible '
            'to you and the other person.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
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
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                      ),
                      child: Text(
                        msg.content,
                        style: Theme.of(context).textTheme.bodyMedium,
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
