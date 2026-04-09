import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_schema.dart';
import '../core/models/chat_conversation_summary.dart';
import '../core/models/chat_message.dart';
import '../core/models/paid_artist_contact.dart';
import '../core/services/chat_service.dart';
import '../core/services/message_indicator_service.dart';
import '../l10n/app_localizations.dart';

/// Private 1:1 chat room between a tattoo artist and a customer only.
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    this.initialReceiverId,
    this.inboxResetTrigger,
  });

  final String? initialReceiverId;

  /// When incremented (e.g. Message tab re-tapped in [MainShellPage]), return to inbox list.
  final ValueNotifier<int>? inboxResetTrigger;

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
  List<PaidArtistContact> _paidArtistContacts = [];
  bool _loadingConversations = false;
  String? _conversationsError;

  @override
  void initState() {
    super.initState();
    _receiverId = widget.initialReceiverId;
    widget.inboxResetTrigger?.addListener(_onInboxResetSignal);
    _subscribeToRealtime();
    if (_receiverId != null) {
      _loadMessages();
    } else {
      setState(() => _loading = false);
      _loadConversations();
    }
  }

  void _onInboxResetSignal() {
    if (!mounted) return;
    _backToInbox();
  }

  /// Conversation → inbox list (same as app bar back).
  void _backToInbox() {
    if (_receiverId == null) return;
    setState(() {
      _receiverId = null;
      _partnerDisplayName = null;
      _messages = [];
      _error = null;
      _receiverEmail = null;
      _receiverMobile = null;
    });
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loadingConversations = true;
      _conversationsError = null;
    });
    try {
      final results = await Future.wait([
        ChatService.fetchConversationSummaries(),
        ChatService.fetchPaidArtistContactsForCustomer(),
      ]);
      if (!mounted) return;
      setState(() {
        _conversations = results[0] as List<ChatConversationSummary>;
        _paidArtistContacts = results[1] as List<PaidArtistContact>;
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

  void _openChatWithPaidArtist(PaidArtistContact contact) {
    setState(() {
      _receiverId = contact.artistUserId;
      _partnerDisplayName = contact.displayName;
      _loading = true;
      _messages = [];
      _error = null;
    });
    _loadMessages();
  }

  @override
  void dispose() {
    widget.inboxResetTrigger?.removeListener(_onInboxResetSignal);
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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.chatSendFailed(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<String> _getDisplayName(String userId, String unknownUserLabel) async {
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
      final display =
          name?.trim().isNotEmpty == true ? name! : unknownUserLabel;
      _displayNames[userId] = display;
      return display;
    } catch (_) {
      return unknownUserLabel;
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _receiverId == null
              ? l10n.chatInboxTitle
              : (_partnerDisplayName ?? l10n.chatPartnerFallbackTitle),
        ),
        leading: _receiverId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _backToInbox,
              )
            : null,
      ),
      body: Column(
        children: [
          if (_receiverId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                l10n.chatPrivacyNotice,
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
                    l10n.chatContactSectionTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (_receiverMobile != null) ...[
                    const SizedBox(height: 6),
                    Text(l10n.chatMobileLine(_receiverMobile!)),
                  ],
                  if (_receiverEmail != null) ...[
                    const SizedBox(height: 4),
                    Text(l10n.chatEmailLine(_receiverEmail!)),
                  ],
                ],
              ),
            ),
          Expanded(
            child: _buildMessageList(l10n),
          ),
          if (_receiverId != null) _buildInputBar(l10n),
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

  Widget _buildInbox(AppLocalizations l10n) {
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
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }
    if (_conversations.isEmpty && _paidArtistContacts.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: _loadConversations,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              l10n.chatYourArtist,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.chatPaidArtistBlurbLong,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 20),
            ..._paidArtistContacts.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _PaidArtistContactCard(
                  contact: c,
                  onMessageArtist: () => _openChatWithPaidArtist(c),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_conversations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadConversations,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.12,
            ),
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.chatInboxEmptyTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.chatInboxEmptyBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              l10n.chatInboxUnlockTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.chatInboxUnlockBody,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final paid = _paidArtistContacts;
    final items = <Widget>[];
    if (paid.isNotEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chatYourArtist,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.chatPaidArtistBlurbShort,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      );
      for (final c in paid) {
        items.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _PaidArtistContactCard(
              contact: c,
              onMessageArtist: () => _openChatWithPaidArtist(c),
            ),
          ),
        );
      }
      items.add(const Divider(height: 24));
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            l10n.chatConversationsSection,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      );
    }

    for (var i = 0; i < _conversations.length; i++) {
      items.add(_conversationListTile(_conversations[i]));
      if (i < _conversations.length - 1) {
        items.add(const Divider(height: 1));
      }
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView(
        padding: EdgeInsets.symmetric(vertical: paid.isNotEmpty ? 4 : 8),
        children: items,
      ),
    );
  }

  Widget _conversationListTile(ChatConversationSummary c) {
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
          style:
              TextStyle(fontWeight: c.awaitingMyReply ? FontWeight.w800 : null),
        ),
      ),
      title: Text(
        c.title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: w),
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
  }

  Widget _buildMessageList(AppLocalizations l10n) {
    if (_receiverId == null) {
      return _buildInbox(l10n);
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
                isTableMissing ? l10n.chatSetupRequired : _error!,
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
                child: Text(l10n.retry),
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
            l10n.chatEmptyConversation,
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
        return _buildMessageBubble(msg, l10n, emphasize: boldThis);
      },
    );
  }

  Widget _buildMessageBubble(
    ChatMessage msg,
    AppLocalizations l10n, {
    bool emphasize = false,
  }) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isMe = msg.senderId == currentUserId;
    // Avatar/name shows the sender (who wrote the message).
    final senderId = msg.senderId;

    return FutureBuilder<String>(
      future: _getDisplayName(senderId, l10n.chatUnknownUser),
      builder: (context, snapshot) {
        final name = snapshot.data ?? l10n.chatUnknownUser;
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

  Widget _buildInputBar(AppLocalizations l10n) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: l10n.chatMessageHint,
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

class _PaidArtistContactCard extends StatelessWidget {
  const _PaidArtistContactCard({
    required this.contact,
    required this.onMessageArtist,
  });

  final PaidArtistContact contact;
  final VoidCallback onMessageArtist;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final avatar = contact.avatarUrl;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.primaryContainer,
                  backgroundImage: avatar != null && avatar.isNotEmpty
                      ? NetworkImage(avatar)
                      : null,
                  child: avatar == null || avatar.isEmpty
                      ? Text(
                          contact.displayName.isNotEmpty
                              ? contact.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(color: scheme.onPrimaryContainer),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    contact.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            if (contact.mobile != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                l10n.chatPhoneLine(contact.mobile!),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
            if (contact.contactEmail != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                l10n.chatEmailLine(contact.contactEmail!),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
            if (contact.mobile == null && contact.contactEmail == null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.chatNoContactYet,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.outline,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onMessageArtist,
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(l10n.chatMessageArtist),
            ),
          ],
        ),
      ),
    );
  }
}
