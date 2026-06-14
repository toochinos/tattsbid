import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_schema.dart';
import '../utils/supabase_list.dart';
import '../models/chat_conversation_summary.dart';
import '../models/chat_message.dart';
import '../utils/user_type_utils.dart';
import 'profile_service.dart';

/// Fetches and sends direct messages.
class ChatService {
  ChatService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Marks all unread messages in a thread as read (current user is receiver).
  /// Uses select-then-update so PostgREST reliably applies [read_at] (update+.isFilter
  /// on null is not reliable on all clients).
  static Future<void> markConversationRead(String partnerId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final now = DateTime.now().toUtc().toIso8601String();

    try {
      final pending = await _client
          .from(SupabaseChatMessages.table)
          .select(SupabaseChatMessages.id)
          .eq(SupabaseChatMessages.receiverId, user.id)
          .eq(SupabaseChatMessages.senderId, partnerId)
          .isFilter(SupabaseChatMessages.readAt, null);

      final rows = mapListFrom(pending);
      if (rows.isEmpty) return;

      final ids = rows
          .map((m) => m[SupabaseChatMessages.id] as String?)
          .whereType<String>()
          .toList();
      if (ids.isEmpty) return;

      const chunkSize = 80;
      for (var i = 0; i < ids.length; i += chunkSize) {
        final end = (i + chunkSize > ids.length) ? ids.length : i + chunkSize;
        final chunk = ids.sublist(i, end);
        await _client
            .from(SupabaseChatMessages.table)
            .update({SupabaseChatMessages.readAt: now}).inFilter(
                SupabaseChatMessages.id, chunk);
      }
    } catch (_) {
      // read_at column missing or RLS — badge uses fallback count until migration.
    }
  }

  /// True when at least one **inbox** thread’s latest message is from the other
  /// person (same as [ChatConversationSummary.awaitingMyReply]). The green
  /// envelope hides after you **send a reply** (last message becomes yours).
  static Future<bool> hasAnyConversationAwaitingMyReply() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final uid = user.id;
    try {
      final drafts = await _fetchInboxEligibleDrafts();
      return drafts.any((s) => s.lastMessageSenderId != uid);
    } catch (_) {
      return false;
    }
  }

  /// App bar title for a thread. Uses the partner’s name for artist ↔ customer chats.
  static Future<String> inboxTitleForPartner(String partnerId) async {
    final user = _client.auth.currentUser;
    if (user == null) return 'Chat';
    final uid = user.id;
    final types = await _fetchUserTypesResolved([uid, partnerId]);
    final myType = types[uid];
    if (!_isArtistCustomerThread(
      myType: myType,
      partnerType: types[partnerId],
    )) {
      return 'Chat';
    }
    final names = await ProfileService.getDisplayNamesByUserIds([partnerId]);
    final n = names[partnerId];
    return (n != null && n.trim().isNotEmpty) ? n.trim() : 'User';
  }

  /// Inbox: all **artist ↔ customer** threads with at least one message. Newest first.
  static Future<List<ChatConversationSummary>>
      fetchConversationSummaries() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to load conversations');
    }
    final uid = user.id;

    final filtered = await _fetchInboxEligibleDrafts();
    final partnerIds = filtered.map((d) => d.partnerId).toList();
    final names = await ProfileService.getDisplayNamesByUserIds(partnerIds);
    final types = await ProfileService.getCanonicalUserTypesByUserIds(
      partnerIds,
    );

    return List<ChatConversationSummary>.generate(filtered.length, (i) {
      final s = filtered[i];
      final displayName = names[s.partnerId];
      final inboxTitle = (displayName != null && displayName.trim().isNotEmpty)
          ? displayName.trim()
          : 'User';

      return ChatConversationSummary(
        partnerId: s.partnerId,
        lastMessagePreview: s.lastMessagePreview,
        lastMessageAt: s.lastMessageAt,
        inboxTitle: inboxTitle,
        awaitingMyReply: s.lastMessageSenderId != uid,
        partnerUserType: types[s.partnerId],
      );
    });
  }

  /// Per-partner last message for threads that qualify for the inbox (artist ↔ customer).
  static Future<
      List<
          ({
            String partnerId,
            String lastMessagePreview,
            DateTime lastMessageAt,
            String lastMessageSenderId,
          })>> _fetchInboxEligibleDrafts() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to load conversations');
    }
    final uid = user.id;

    final res = await _client
        .from(SupabaseChatMessages.table)
        .select()
        .or(
          '${SupabaseChatMessages.senderId}.eq.$uid,${SupabaseChatMessages.receiverId}.eq.$uid',
        )
        .order(SupabaseChatMessages.createdAt, ascending: false)
        .limit(500);

    final rows = mapListFrom(res);
    final seenPartners = <String>{};
    final drafts = <({
      String partnerId,
      String lastMessagePreview,
      DateTime lastMessageAt,
      String lastMessageSenderId,
    })>[];

    for (final row in rows) {
      final senderId = row[SupabaseChatMessages.senderId] as String?;
      final receiverId = row[SupabaseChatMessages.receiverId] as String?;
      if (senderId == null || receiverId == null) continue;
      final partner = senderId == uid ? receiverId : senderId;
      if (seenPartners.contains(partner)) continue;
      seenPartners.add(partner);

      final content = row['message'] as String? ??
          row[SupabaseChatMessages.content] as String? ??
          '';
      final createdAtStr = row[SupabaseChatMessages.createdAt] as String?;
      final createdAt = createdAtStr != null
          ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
          : DateTime.now();

      drafts.add((
        partnerId: partner,
        lastMessagePreview: content,
        lastMessageAt: createdAt,
        lastMessageSenderId: senderId,
      ));
    }

    drafts.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

    final allPartnerIds = drafts.map((d) => d.partnerId).toList();
    final userIdsForTypes = <String>{uid, ...allPartnerIds}.toList();
    final types = await _fetchUserTypesResolved(userIdsForTypes);
    final myType = types[uid];

    final filtered = <({
      String partnerId,
      String lastMessagePreview,
      DateTime lastMessageAt,
      String lastMessageSenderId,
    })>[];
    for (final s in drafts) {
      final partnerId = s.partnerId;
      final partnerType = types[partnerId];
      if (!_isArtistCustomerThread(
        myType: myType,
        partnerType: partnerType,
      )) {
        continue;
      }
      filtered.add((
        partnerId: s.partnerId,
        lastMessagePreview: s.lastMessagePreview,
        lastMessageAt: s.lastMessageAt,
        lastMessageSenderId: s.lastMessageSenderId,
      ));
    }

    filtered.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return filtered;
  }

  /// True when [myType] and [partnerType] are one customer + one tattoo artist.
  static bool _isArtistCustomerThread({
    required String? myType,
    required String? partnerType,
  }) {
    var mt = myType;
    var pt = partnerType;

    if (mt == 'tattoo_artist' && pt == null) pt = 'customer';
    if (mt == 'customer' && pt == null) pt = 'tattoo_artist';
    if (pt == 'tattoo_artist' && mt == null) mt = 'customer';
    if (pt == 'customer' && mt == null) mt = 'tattoo_artist';

    final iAmCustomer = mt == 'customer';
    final iAmArtist = mt == 'tattoo_artist';
    final partnerIsCustomer = pt == 'customer';
    final partnerIsArtist = pt == 'tattoo_artist';

    return (iAmCustomer && partnerIsArtist) || (iAmArtist && partnerIsCustomer);
  }

  /// Raw [profiles.user_type] values from Supabase.
  static Future<Map<String, String?>> _fetchUserTypesRaw(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    final res = await _client
        .from(SupabaseProfiles.table)
        .select('${SupabaseProfiles.id}, ${SupabaseProfiles.userType}')
        .inFilter(SupabaseProfiles.id, ids);
    final map = <String, String?>{};
    for (final row in mapListFrom(res)) {
      final id = row[SupabaseProfiles.id] as String?;
      if (id != null) {
        map[id] = row[SupabaseProfiles.userType] as String?;
      }
    }
    return map;
  }

  /// Canonical [user_type] plus fallbacks: tattoo request owners → customer,
  /// bid placers → tattoo artist (when profile type is missing).
  static Future<Map<String, String?>> _fetchUserTypesResolved(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    final unique = ids.toSet().toList();
    final raw = await _fetchUserTypesRaw(unique);
    final map = <String, String?>{};
    for (final id in unique) {
      map[id] = canonicalUserType(raw[id]);
    }

    try {
      final tr = await _client
          .from(SupabaseTattooRequests.table)
          .select(SupabaseTattooRequests.userId)
          .inFilter(SupabaseTattooRequests.userId, unique);
      final owners = <String>{};
      for (final m in mapListFrom(tr)) {
        final u = m[SupabaseTattooRequests.userId] as String?;
        if (u != null) owners.add(u);
      }
      for (final id in unique) {
        if (map[id] == null && owners.contains(id)) {
          map[id] = 'customer';
        }
      }
    } catch (_) {}

    try {
      final bd = await _client
          .from(SupabaseBids.table)
          .select(SupabaseBids.bidderId)
          .inFilter(SupabaseBids.bidderId, unique);
      final bidders = <String>{};
      for (final m in mapListFrom(bd)) {
        final b = m[SupabaseBids.bidderId] as String?;
        if (b != null) bidders.add(b);
      }
      for (final id in unique) {
        if (map[id] == null && bidders.contains(id)) {
          map[id] = 'tattoo_artist';
        }
      }
    } catch (_) {}

    return map;
  }

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

    return mapListFrom(res).map(ChatMessage.fromJson).toList();
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
