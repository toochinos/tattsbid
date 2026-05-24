import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_schema.dart';
import '../utils/supabase_list.dart';
import '../models/chat_conversation_summary.dart';
import '../models/chat_message.dart';
import '../models/paid_artist_contact.dart';
import '../utils/user_type_utils.dart';
import 'profile_service.dart';

/// Fetches and sends direct messages.
class ChatService {
  ChatService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static bool _paymentStatusIsPaid(dynamic raw) {
    if (raw == null) return false;
    final s = raw.toString().trim().toLowerCase();
    return s == 'paid';
  }

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

  /// App bar title for a thread. Uses the partner’s name for inbox-listed
  /// threads (customer-first explore chats, or **paid winning artist** /
  /// **paid customer** after Stripe deposit).
  static Future<String> inboxTitleForPartner(String partnerId) async {
    final user = _client.auth.currentUser;
    if (user == null) return 'Chat';
    final uid = user.id;
    final firstSender = await _firstMessageSenderInThread(uid, partnerId);
    final types = await _fetchUserTypesResolved([uid, partnerId]);
    final names = await ProfileService.getDisplayNamesByUserIds([partnerId]);
    final myType = types[uid];
    final okFirst = _isCustomerFirstMessageInArtistCustomerThread(
      myId: uid,
      partnerId: partnerId,
      myType: myType,
      partnerType: types[partnerId],
      firstMessageSenderId: firstSender,
    );
    final paidOk =
        (await _paidPartnerIdsForInbox(uid, myType)).contains(partnerId);
    if (!okFirst && !paidOk) return 'Chat';
    final n = names[partnerId];
    return (n != null && n.trim().isNotEmpty) ? n.trim() : 'User';
  }

  /// Inbox: **artist ↔ customer** threads where the customer sent the first
  /// message from Explore, **or** winning bid [payment_status] is `paid` with
  /// that partner (shows a placeholder row before any message). Newest first.
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

  /// Winning artists: [bids.payment_status] `paid` or paid [contact_unlocks] row.
  /// Used on the Message tab when there are no threads yet.
  static Future<List<PaidArtistContact>>
      fetchPaidArtistContactsForCustomer() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final reqRes = await _client
          .from(SupabaseTattooRequests.table)
          .select(
            '${SupabaseTattooRequests.id},${SupabaseTattooRequests.winningBidId}',
          )
          .eq(SupabaseTattooRequests.userId, user.id);

      final requestIds = <String>[];
      final winIds = <String>[];
      for (final m in mapListFrom(reqRes)) {
        final rid = m[SupabaseTattooRequests.id] as String?;
        final wb = m[SupabaseTattooRequests.winningBidId] as String?;
        if (rid != null && rid.isNotEmpty) requestIds.add(rid);
        if (wb != null && wb.isNotEmpty) winIds.add(wb);
      }
      if (requestIds.isEmpty) {
        final out = <PaidArtistContact>[];
        final seen = <String>{};
        await _appendPaidArtistContactsFromUnlockRows(user.id, out, seen);
        return out;
      }

      final allForRequests = await _client
          .from(SupabaseBids.table)
          .select()
          .inFilter(SupabaseBids.requestId, requestIds);
      final winSet = winIds.toSet();
      final paidBids = mapListFrom(allForRequests)
          .where((m) => _paymentStatusIsPaid(m[SupabaseBids.paymentStatus]))
          .toList();
      paidBids.sort((a, b) {
        final aid = a[SupabaseBids.id] as String?;
        final bid = b[SupabaseBids.id] as String?;
        final aw = aid != null && winSet.contains(aid);
        final bw = bid != null && winSet.contains(bid);
        if (aw && !bw) return -1;
        if (!aw && bw) return 1;
        return 0;
      });
      final bidsRes = paidBids;

      final artistIds = <String>{};
      for (final m in bidsRes) {
        final bidder = m[SupabaseBids.bidderId] as String?;
        if (bidder != null && bidder.isNotEmpty) artistIds.add(bidder);
      }

      final out = <PaidArtistContact>[];
      final seenArtists = <String>{};

      if (artistIds.isEmpty) {
        await _appendPaidArtistContactsFromUnlockRows(
          user.id,
          out,
          seenArtists,
        );
        return out;
      }

      final profilesRes = await _client
          .from(SupabaseProfiles.table)
          .select(
            '${SupabaseProfiles.id},${SupabaseProfiles.displayName},'
            '${SupabaseProfiles.contactEmail},${SupabaseProfiles.mobile},'
            '${SupabaseProfiles.avatarUrl}',
          )
          .inFilter(SupabaseProfiles.id, artistIds.toList());

      final profileById = <String, Map<String, dynamic>>{};
      for (final m in mapListFrom(profilesRes)) {
        final id = m[SupabaseProfiles.id] as String?;
        if (id != null) profileById[id] = m;
      }

      for (final m in bidsRes) {
        final bidId = m[SupabaseBids.id] as String?;
        final requestId = m[SupabaseBids.requestId] as String?;
        final bidderId = m[SupabaseBids.bidderId] as String?;
        if (bidId == null || requestId == null || bidderId == null) continue;
        if (!seenArtists.add(bidderId)) continue;

        final prof = profileById[bidderId];
        final name = prof?[SupabaseProfiles.displayName] as String?;
        final displayName =
            (name != null && name.trim().isNotEmpty) ? name.trim() : 'Artist';
        final mobileRaw = prof?[SupabaseProfiles.mobile] as String?;
        final emailRaw = prof?[SupabaseProfiles.contactEmail] as String?;
        final avatarRaw = prof?[SupabaseProfiles.avatarUrl] as String?;

        out.add(
          PaidArtistContact(
            artistUserId: bidderId,
            requestId: requestId,
            bidId: bidId,
            displayName: displayName,
            mobile: mobileRaw != null && mobileRaw.trim().isNotEmpty
                ? mobileRaw.trim()
                : null,
            contactEmail: emailRaw != null && emailRaw.trim().isNotEmpty
                ? emailRaw.trim()
                : null,
            avatarUrl: avatarRaw != null && avatarRaw.trim().isNotEmpty
                ? avatarRaw.trim()
                : null,
          ),
        );
      }

      await _appendPaidArtistContactsFromUnlockRows(
        user.id,
        out,
        seenArtists,
      );
      return out;
    } catch (e, st) {
      debugPrint('fetchPaidArtistContactsForCustomer: $e\n$st');
      return [];
    }
  }

  /// Adds [PaidArtistContact] rows for [contact_unlocks] paid without a matching paid bid row.
  static Future<void> _appendPaidArtistContactsFromUnlockRows(
    String customerId,
    List<PaidArtistContact> out,
    Set<String> seenArtists,
  ) async {
    try {
      final unlockRes = await _client
          .from(SupabaseContactUnlocks.table)
          .select()
          .eq(SupabaseContactUnlocks.userId, customerId.trim())
          .eq(SupabaseContactUnlocks.status, SupabaseContactUnlocks.statusPaid);

      final pending = <({String artistId, String requestId})>[];
      for (final m in mapListFrom(unlockRes)) {
        final artistId = m[SupabaseContactUnlocks.artistId] as String?;
        final requestId = m[SupabaseContactUnlocks.requestId] as String?;
        if (artistId == null ||
            artistId.isEmpty ||
            requestId == null ||
            requestId.isEmpty) {
          continue;
        }
        if (seenArtists.contains(artistId)) continue;
        pending.add((artistId: artistId, requestId: requestId));
      }
      if (pending.isEmpty) return;

      final newArtistIds = pending.map((p) => p.artistId).toSet().toList();
      final profilesRes = await _client
          .from(SupabaseProfiles.table)
          .select(
            '${SupabaseProfiles.id},${SupabaseProfiles.displayName},'
            '${SupabaseProfiles.contactEmail},${SupabaseProfiles.mobile},'
            '${SupabaseProfiles.avatarUrl}',
          )
          .inFilter(SupabaseProfiles.id, newArtistIds);

      final profileById = <String, Map<String, dynamic>>{};
      for (final m in mapListFrom(profilesRes)) {
        final id = m[SupabaseProfiles.id] as String?;
        if (id != null) profileById[id] = m;
      }

      for (final p in pending) {
        if (!seenArtists.add(p.artistId)) continue;

        final req = await _client
            .from(SupabaseTattooRequests.table)
            .select(SupabaseTattooRequests.winningBidId)
            .eq(SupabaseTattooRequests.id, p.requestId)
            .maybeSingle();
        final winBidId = req?[SupabaseTattooRequests.winningBidId] as String?;
        if (winBidId == null || winBidId.isEmpty) continue;

        final prof = profileById[p.artistId];
        final name = prof?[SupabaseProfiles.displayName] as String?;
        final displayName =
            (name != null && name.trim().isNotEmpty) ? name.trim() : 'Artist';
        final mobileRaw = prof?[SupabaseProfiles.mobile] as String?;
        final emailRaw = prof?[SupabaseProfiles.contactEmail] as String?;
        final avatarRaw = prof?[SupabaseProfiles.avatarUrl] as String?;

        out.add(
          PaidArtistContact(
            artistUserId: p.artistId,
            requestId: p.requestId,
            bidId: winBidId,
            displayName: displayName,
            mobile: mobileRaw != null && mobileRaw.trim().isNotEmpty
                ? mobileRaw.trim()
                : null,
            contactEmail: emailRaw != null && emailRaw.trim().isNotEmpty
                ? emailRaw.trim()
                : null,
            avatarUrl: avatarRaw != null && avatarRaw.trim().isNotEmpty
                ? avatarRaw.trim()
                : null,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('_appendPaidArtistContactsFromUnlockRows: $e\n$st');
    }
  }

  /// Per-partner last message for threads that qualify for the inbox (customer
  /// sent first message in an artist↔customer pair).
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

    final firstSenders = await Future.wait(
      allPartnerIds.map((p) => _firstMessageSenderInThread(uid, p)),
    );

    // After Stripe deposit, the thread may start with the artist — still show in inbox.
    final paidPartnerAllowList = await _paidPartnerIdsForInbox(uid, myType);

    final filtered = <({
      String partnerId,
      String lastMessagePreview,
      DateTime lastMessageAt,
      String lastMessageSenderId,
    })>[];
    for (var i = 0; i < drafts.length; i++) {
      final s = drafts[i];
      final partnerId = s.partnerId;
      final firstSender = firstSenders[i];
      final partnerType = types[partnerId];
      final inboxByFirstMessage = _isCustomerFirstMessageInArtistCustomerThread(
        myId: uid,
        partnerId: partnerId,
        myType: myType,
        partnerType: partnerType,
        firstMessageSenderId: firstSender,
      );
      final inboxByPaidJob = paidPartnerAllowList.contains(partnerId);
      if (!inboxByFirstMessage && !inboxByPaidJob) {
        continue;
      }
      filtered.add((
        partnerId: s.partnerId,
        lastMessagePreview: s.lastMessagePreview,
        lastMessageAt: s.lastMessageAt,
        lastMessageSenderId: s.lastMessageSenderId,
      ));
    }

    // Paid deposit (winning bid) unlocks chat even before any message exists —
    // otherwise the Message tab stays empty until someone sends first.
    final shownPartnerIds = filtered.map((s) => s.partnerId).toSet();
    for (final paidPartnerId in paidPartnerAllowList) {
      if (shownPartnerIds.contains(paidPartnerId)) continue;
      shownPartnerIds.add(paidPartnerId);
      filtered.add((
        partnerId: paidPartnerId,
        lastMessagePreview: 'Deposit paid — tap to chat',
        lastMessageAt: DateTime.now().toUtc(),
        lastMessageSenderId: uid,
      ));
    }

    filtered.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return filtered;
  }

  /// Artists unlocked via [contact_unlocks] with status `paid` (Stripe or RPC).
  static Future<Set<String>> _artistIdsFromPaidContactUnlocksForCustomer(
    String customerId,
  ) async {
    try {
      final res = await _client
          .from(SupabaseContactUnlocks.table)
          .select(SupabaseContactUnlocks.artistId)
          .eq(SupabaseContactUnlocks.userId, customerId.trim())
          .eq(SupabaseContactUnlocks.status, SupabaseContactUnlocks.statusPaid);
      final out = <String>{};
      for (final m in mapListFrom(res)) {
        final a = m[SupabaseContactUnlocks.artistId] as String?;
        if (a != null && a.isNotEmpty) out.add(a);
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  /// Customer ids with a paid [contact_unlocks] row for this artist.
  static Future<Set<String>> _customerIdsFromPaidContactUnlocksForArtist(
    String artistId,
  ) async {
    try {
      final res = await _client
          .from(SupabaseContactUnlocks.table)
          .select(SupabaseContactUnlocks.userId)
          .eq(SupabaseContactUnlocks.artistId, artistId.trim())
          .eq(SupabaseContactUnlocks.status, SupabaseContactUnlocks.statusPaid);
      final out = <String>{};
      for (final m in mapListFrom(res)) {
        final u = m[SupabaseContactUnlocks.userId] as String?;
        if (u != null && u.isNotEmpty) out.add(u);
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  /// Winning artists: [bids.payment_status] `paid` **or** paid [contact_unlocks].
  static Future<Set<String>> _paidWinningArtistIdsForCustomer(
    String customerId,
  ) async {
    try {
      final res = await _client
          .from(SupabaseTattooRequests.table)
          .select(SupabaseTattooRequests.winningBidId)
          .eq(SupabaseTattooRequests.userId, customerId);
      final bidIds = <String>[];
      for (final m in mapListFrom(res)) {
        final bidId = m[SupabaseTattooRequests.winningBidId] as String?;
        if (bidId != null && bidId.isNotEmpty) bidIds.add(bidId);
      }
      final fromBids = <String>{};
      if (bidIds.isNotEmpty) {
        final bidsRes = await _client
            .from(SupabaseBids.table)
            .select()
            .inFilter(SupabaseBids.id, bidIds);
        for (final m in mapListFrom(bidsRes)) {
          if (!_paymentStatusIsPaid(m[SupabaseBids.paymentStatus])) continue;
          final b = m[SupabaseBids.bidderId] as String?;
          if (b != null) fromBids.add(b);
        }
      }
      final fromUnlocks =
          await _artistIdsFromPaidContactUnlocksForCustomer(customerId);
      return {...fromBids, ...fromUnlocks};
    } catch (_) {
      return {};
    }
  }

  /// True if the signed-in **customer** has a request where [artistUserId] is the
  /// winning bidder and that bid’s [bids.payment_status] is `paid`.
  static Future<bool> customerHasPaidDepositWithArtist(
    String artistUserId,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final id = artistUserId.trim();
    if (id.isEmpty) return false;
    final paid = await _paidWinningArtistIdsForCustomer(user.id);
    return paid.contains(id);
  }

  /// Customers whose winning bid is paid **or** who have a paid [contact_unlocks] with this artist.
  static Future<Set<String>> _customerIdsForPaidWinsAsArtist(
    String artistId,
  ) async {
    try {
      final bidRes = await _client
          .from(SupabaseBids.table)
          .select()
          .eq(SupabaseBids.bidderId, artistId);
      final bidIds = <String>[];
      for (final m in mapListFrom(bidRes)) {
        if (!_paymentStatusIsPaid(m[SupabaseBids.paymentStatus])) continue;
        final id = m[SupabaseBids.id] as String?;
        if (id != null) bidIds.add(id);
      }
      final fromBids = <String>{};
      if (bidIds.isNotEmpty) {
        final reqRows = await _client
            .from(SupabaseTattooRequests.table)
            .select(SupabaseTattooRequests.userId)
            .inFilter(SupabaseTattooRequests.winningBidId, bidIds);
        for (final m in mapListFrom(reqRows)) {
          final u = m[SupabaseTattooRequests.userId] as String?;
          if (u != null) fromBids.add(u);
        }
      }
      final fromUnlocks =
          await _customerIdsFromPaidContactUnlocksForArtist(artistId);
      return {...fromBids, ...fromUnlocks};
    } catch (_) {
      return {};
    }
  }

  static Future<Set<String>> _paidPartnerIdsForInbox(
    String uid,
    String? myType,
  ) async {
    final t = myType?.trim();
    if (t == 'customer') {
      return _paidWinningArtistIdsForCustomer(uid);
    }
    if (t == 'tattoo_artist') {
      return _customerIdsForPaidWinsAsArtist(uid);
    }
    return {};
  }

  /// True when [myId] and [partnerId] are one customer + one tattoo artist and
  /// the **first** message in the thread was sent by the customer.
  static bool _isCustomerFirstMessageInArtistCustomerThread({
    required String myId,
    required String partnerId,
    required String? myType,
    required String? partnerType,
    required String? firstMessageSenderId,
  }) {
    if (firstMessageSenderId == null) return false;

    var mt = myType;
    var pt = partnerType;

    // Infer the missing role in a 1:1 tattoo app thread.
    if (mt == 'tattoo_artist' && pt == null) pt = 'customer';
    if (mt == 'customer' && pt == null) pt = 'tattoo_artist';
    if (pt == 'tattoo_artist' && mt == null) mt = 'customer';
    if (pt == 'customer' && mt == null) mt = 'tattoo_artist';

    final iAmCustomer = mt == 'customer';
    final iAmArtist = mt == 'tattoo_artist';
    final partnerIsCustomer = pt == 'customer';
    final partnerIsArtist = pt == 'tattoo_artist';

    final isArtistCustomerPair =
        (iAmCustomer && partnerIsArtist) || (iAmArtist && partnerIsCustomer);
    if (!isArtistCustomerPair) return false;

    final customerId = partnerIsCustomer ? partnerId : myId;
    return firstMessageSenderId == customerId;
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

  /// First message in the 1:1 thread (by [created_at]), if any.
  static Future<String?> _firstMessageSenderInThread(
    String myId,
    String partnerId,
  ) async {
    final res = await _client
        .from(SupabaseChatMessages.table)
        .select(SupabaseChatMessages.senderId)
        .or(
          'and(${SupabaseChatMessages.senderId}.eq.$myId,${SupabaseChatMessages.receiverId}.eq.$partnerId),and(${SupabaseChatMessages.senderId}.eq.$partnerId,${SupabaseChatMessages.receiverId}.eq.$myId)',
        )
        .order(SupabaseChatMessages.createdAt, ascending: true)
        .limit(1);
    final list = mapListFrom(res);
    if (list.isEmpty) return null;
    final row = list.first;
    return row[SupabaseChatMessages.senderId] as String?;
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
