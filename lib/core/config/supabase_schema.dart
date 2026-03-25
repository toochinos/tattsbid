/// Supabase schema reference for Cursor and codebase alignment.
///
/// This file documents the public.profiles table structure so Cursor
/// and developers can see the exact mapping between Dart models and
/// Supabase columns.
///
/// Table: public.profiles
/// - id (uuid, PK, references auth.users)
/// - display_name (text)
/// - avatar_url (text)
/// - location (text)
/// - bio (text)
/// - user_type (text): 'tattoo_artist' or 'customer'
/// - role (text, optional): 'artist' or 'customer' — Request Detail UI; may be null
/// - rating (numeric, optional): average rating for Artists directory when added
/// - contact_email (text, optional): public contact email
/// - mobile (text, optional): phone / mobile
/// - portfolio_urls (jsonb): array of image URLs for tattoo artist portfolio (max 10 in app)
/// - has_accepted_terms (boolean, default false): user accepted agreement
/// - created_at (timestamptz)
/// - updated_at (timestamptz)
///
/// Dart model: UserProfile (lib/core/models/user_profile.dart)
/// Column mapping:
///   display_name  -> displayName
///   avatar_url    -> avatarUrl
///   location      -> location
library;

/// Supabase column names for the profiles table.
/// Use these when building queries to avoid typos.
abstract final class SupabaseProfiles {
  SupabaseProfiles._();

  static const String table = 'profiles';
  static const String schema = 'public';

  static const String id = 'id';
  static const String displayName = 'display_name';
  static const String avatarUrl = 'avatar_url';
  static const String location = 'location';
  static const String bio = 'bio';
  static const String userType = 'user_type';
  static const String role = 'role';
  static const String contactEmail = 'contact_email';
  static const String mobile = 'mobile';
  static const String portfolioUrls = 'portfolio_urls';
  static const String hasAcceptedTerms = 'has_accepted_terms';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';

  /// Select clause for full profile fetch.
  static const String selectAll =
      '$displayName, $avatarUrl, $location, $bio, $userType, $contactEmail, $mobile, $portfolioUrls';
}

/// Supabase column names for the tattoo_requests table.
abstract final class SupabaseTattooRequests {
  SupabaseTattooRequests._();

  static const String table = 'tattoo_requests';
  static const String schema = 'public';

  static const String id = 'id';
  static const String userId = 'user_id';
  static const String imageUrl = 'image_url';
  static const String description = 'description';
  static const String placement = 'placement';
  static const String size = 'size';
  static const String colourPreference = 'colour_preference';
  static const String artistCreativeFreedom = 'artist_creative_freedom';
  static const String timeframe = 'timeframe';
  static const String startingBid = 'starting_bid';
  static const String winningBidId = 'winning_bid_id';
  static const String status = 'status';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

/// Supabase column names for the chat_messages table.
abstract final class SupabaseChatMessages {
  SupabaseChatMessages._();

  static const String table = 'chat_messages';
  static const String schema = 'public';

  static const String id = 'id';
  static const String senderId = 'sender_id';
  static const String receiverId = 'receiver_id';
  static const String content = 'content';
  static const String createdAt = 'created_at';

  /// When set, the receiver has seen this message. Null = unread for receiver.
  static const String readAt = 'read_at';
}

/// Table: public.contact_unlocks — post–Stripe deposit; unlocks artist contact on request detail.
abstract final class SupabaseContactUnlocks {
  SupabaseContactUnlocks._();

  static const String table = 'contact_unlocks';

  static const String id = 'id';
  static const String userId = 'user_id';
  static const String artistId = 'artist_id';
  static const String requestId = 'request_id';
  static const String status = 'status';
  static const String depositAmount = 'deposit_amount';
  static const String createdAt = 'created_at';

  static const String statusPaid = 'paid';
}

/// Supabase column names for the bids table.
abstract final class SupabaseBids {
  SupabaseBids._();

  static const String table = 'bids';
  static const String schema = 'public';

  static const String id = 'id';
  static const String requestId = 'request_id';
  static const String bidderId = 'bidder_id';
  static const String amount = 'amount';
  static const String createdAt = 'created_at';
  static const String paymentStatus = 'payment_status';
}
