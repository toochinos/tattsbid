import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/artist_review.dart';
import '../core/models/user_profile.dart';
import '../core/services/chat_service.dart';
import '../core/services/profile_service.dart';
import '../core/services/review_service.dart';
import '../widgets/clean_hands_icon.dart';
import '../widgets/tattoo_review_rating_widgets.dart';
import 'chat_page.dart';

/// Read-only profile for another user (e.g. opened from Artists directory).
class PublicArtistProfilePage extends StatefulWidget {
  const PublicArtistProfilePage({
    super.key,
    required this.userId,
    this.fromArtistsDirectory = false,
  });

  final String userId;

  /// When true (Artists tab list → profile), chat and contact are hidden (browse-only).
  /// When false, email/phone/chat show only if the winning bid has [bids.payment_status]
  /// `paid` for this customer (see [ChatService.customerHasPaidDepositWithArtist]).
  final bool fromArtistsDirectory;

  @override
  State<PublicArtistProfilePage> createState() =>
      _PublicArtistProfilePageState();
}

class _PublicArtistProfilePageState extends State<PublicArtistProfilePage> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  List<ArtistReview> _reviews = [];
  final TextEditingController _reviewCommentController =
      TextEditingController();

  /// Own controller, not primary; [keepScrollOffset] false avoids PageStorage
  /// restoring a bad scroll value (can throw `bool` vs `double?` in
  /// [ScrollPosition.restoreScrollOffset]) when nested under [ExpansionTile].
  final ScrollController _reviewsListScrollController =
      ScrollController(keepScrollOffset: false);
  int _draftRating = 0;
  int _draftCleanliness = 0;
  bool _submittingReview = false;

  /// Chat + email/phone only after customer has paid (completed request with this artist).
  bool _showContactAndChat = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reviewCommentController.dispose();
    _reviewsListScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await ProfileService.getProfileByUserId(widget.userId);
      var reviews = <ArtistReview>[];
      try {
        reviews = await ReviewService.fetchForArtist(widget.userId);
      } catch (_) {
        // RLS/offline: still show profile
      }
      var allowContact = true;
      if (widget.fromArtistsDirectory) {
        // Browsing Artists directory — never show chat/contact on profile.
        allowContact = false;
      } else if (p != null) {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        final my = await ProfileService.getCurrentProfile();
        if (uid != null &&
            uid != widget.userId &&
            my?.userType == 'customer' &&
            p.userType == 'tattoo_artist') {
          allowContact =
              await ChatService.customerHasPaidDepositWithArtist(widget.userId);
        }
      }
      if (!mounted) return;
      final me = Supabase.instance.client.auth.currentUser?.id;
      ArtistReview? mine;
      if (me != null) {
        for (final r in reviews) {
          if (r.userId == me) {
            mine = r;
            break;
          }
        }
      }
      setState(() {
        _profile = p;
        _reviews = reviews;
        if (mine != null &&
            _reviewCommentController.text.trim().isEmpty &&
            _draftRating == 0 &&
            _draftCleanliness == 0) {
          _reviewCommentController.text = mine.comment;
          _draftRating = mine.rating;
          _draftCleanliness = mine.cleanliness;
        }
        _showContactAndChat = allowContact;
        _loading = false;
        if (p == null) {
          _error = 'Profile not found';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _titleForType(String? t) {
    switch (t) {
      case 'tattoo_artist':
        return 'Tattoo artist';
      case 'customer':
        return 'Customer';
      default:
        return 'Profile';
    }
  }

  bool get _isOwnProfile {
    final me = Supabase.instance.client.auth.currentUser?.id;
    return me != null && me == widget.userId;
  }

  ArtistReview? get _myExistingReview {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null) return null;
    for (final r in _reviews) {
      if (r.userId == me) return r;
    }
    return null;
  }

  void _openChat() {
    if (_isOwnProfile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can’t chat with yourself.')),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(initialReceiverId: widget.userId),
      ),
    );
  }

  String get _appBarTitle {
    if (_loading) return 'Profile';
    final p = _profile;
    if (p == null) return 'Profile';
    final n = p.displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Profile';
  }

  Future<void> _refreshReviewsOnly() async {
    try {
      final list = await ReviewService.fetchForArtist(widget.userId);
      if (!mounted) return;
      setState(() {
        _reviews = list;
        final mine = _myExistingReview;
        if (mine != null &&
            _reviewCommentController.text.trim().isEmpty &&
            _draftRating == 0 &&
            _draftCleanliness == 0) {
          _reviewCommentController.text = mine.comment;
          _draftRating = mine.rating;
          _draftCleanliness = mine.cleanliness;
        }
      });
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> _submitReview() async {
    final comment = _reviewCommentController.text.trim();
    if (_draftRating < 1 ||
        _draftRating > 5 ||
        _draftCleanliness < 1 ||
        _draftCleanliness > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select both Rating and Cleanliness (1–5 stars each).',
          ),
        ),
      );
      return;
    }
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a comment.')),
      );
      return;
    }
    setState(() => _submittingReview = true);
    try {
      final result = await ReviewService.submitReview(
        artistId: widget.userId,
        rating: _draftRating,
        cleanliness: _draftCleanliness,
        comment: comment,
      );
      if (!mounted) return;
      _reviewCommentController.clear();
      setState(() {
        _draftRating = 0;
        _draftCleanliness = 0;
        _submittingReview = false;
      });
      await _refreshReviewsOnly();
      if (!mounted) return;
      final msg = switch (result) {
        ReviewSubmitResult.created => 'Thanks — your review was posted.',
        ReviewSubmitResult.updated =>
          'You have already reviewed this artist. Your review was updated.',
        ReviewSubmitResult.alreadyReviewed =>
          'You have already reviewed this artist',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submittingReview = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit review right now. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(_appBarTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(context, _profile!),
    );
  }

  Widget _buildContent(BuildContext context, UserProfile profile) {
    final name = profile.displayName?.trim().isNotEmpty == true
        ? profile.displayName!
        : 'Artist';
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CircleAvatar(
              radius: 56,
              backgroundColor: scheme.primaryContainer,
              backgroundImage: profile.avatarUrl != null &&
                      profile.avatarUrl!.trim().isNotEmpty
                  ? NetworkImage(profile.avatarUrl!)
                  : null,
              child: profile.avatarUrl == null ||
                      profile.avatarUrl!.trim().isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: scheme.onPrimaryContainer,
                              ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _titleForType(profile.userType),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.outline,
                ),
          ),
          if (!_isOwnProfile && _showContactAndChat) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openChat,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Chat'),
            ),
          ],
          if (profile.location != null &&
              profile.location!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 20, color: scheme.outline),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    profile.location!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ],
          if (profile.userType == 'tattoo_artist') ...[
            const SizedBox(height: 28),
            Text(
              'Reviews',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
            ),
            const SizedBox(height: 12),
            if (_reviews.isEmpty)
              Text(
                'No reviews yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.outline,
                    ),
              )
            else ...[
              TattooDualRatingAveragesHeader(
                experienceAverage: ReviewService.averageExperience(_reviews),
                cleanlinessAverage: ReviewService.averageCleanliness(_reviews),
              ),
              const SizedBox(height: 8),
              Material(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child:                   ExpansionTile(
                    // ValueKey: avoid PageStorageKey colliding with nested scroll
                    // offset buckets (same class of bool/double restore bugs).
                    key: ValueKey<String>('reviews_tile_${widget.userId}'),
                    initiallyExpanded: false,
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(
                      Icons.rate_review_outlined,
                      color: scheme.primary,
                    ),
                    title: Text(
                      'Previous reviews',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    subtitle: Text(
                      '${_reviews.length} review${_reviews.length == 1 ? '' : 's'} · tap to expand',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.outline,
                          ),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    children: [
                      SizedBox(
                        height: ((MediaQuery.sizeOf(context).height * 0.38)
                                .clamp(220.0, 400.0))
                            .toDouble(),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  scheme.outlineVariant.withValues(alpha: 0.45),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Scrollbar(
                              controller: _reviewsListScrollController,
                              thumbVisibility: _reviews.length > 2,
                              child: ListView.separated(
                                controller: _reviewsListScrollController,
                                primary: false,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  12,
                                ),
                                physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                ),
                                itemCount: _reviews.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final review = _reviews[index];
                                  final rating =
                                      (review['rating'] as num?)?.toDouble() ??
                                          0.0;
                                  final cleanliness =
                                      (review['cleanliness'] as num?)
                                              ?.toDouble() ??
                                          0.0;
                                  return _buildReviewListCard(
                                    context,
                                    review,
                                    rating: rating,
                                    cleanliness: cleanliness,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_reviews.isNotEmpty) const SizedBox(height: 16),
            if (Supabase.instance.client.auth.currentUser != null &&
                !_isOwnProfile) ...[
              const SizedBox(height: 8),
              Text(
                _myExistingReview == null
                    ? 'Write a review'
                    : 'Edit your review',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TattooExperienceStarPicker(
                value: _draftRating,
                enabled: !_submittingReview,
                onChanged: (v) => setState(() => _draftRating = v),
              ),
              const SizedBox(height: 8),
              TattooCleanlinessStarPicker(
                value: _draftCleanliness,
                enabled: !_submittingReview,
                onChanged: (v) => setState(() => _draftCleanliness = v),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _reviewCommentController,
                enabled: !_submittingReview,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Share your experience…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor:
                      scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _submittingReview ? null : _submitReview,
                child: _submittingReview
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Text('Submit review'),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Portfolio',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
            ),
            if (profile.portfolioUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: profile.portfolioUrls.length,
                itemBuilder: (context, index) {
                  final url = profile.portfolioUrls[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: Colors.white,
                        child: Icon(Icons.broken_image, color: scheme.outline),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
          if (profile.userType == 'tattoo_artist' && _showContactAndChat) ...[
            const SizedBox(height: 32),
            Text(
              'Contact',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            if (profile.contactEmail != null &&
                profile.contactEmail!.trim().isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: SelectableText(profile.contactEmail!),
              ),
            if (profile.mobile != null && profile.mobile!.trim().isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined),
                title: const Text('Mobile'),
                subtitle: SelectableText(profile.mobile!),
              ),
            if ((profile.contactEmail == null ||
                    profile.contactEmail!.trim().isEmpty) &&
                (profile.mobile == null || profile.mobile!.trim().isEmpty))
              Text(
                'No contact details on file.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.outline,
                    ),
              ),
          ],
        ],
      ),
    );
  }

  /// One review entry inside the scrollable reviews list (plain rows, no field chrome).
  /// [rating] / [cleanliness] must come from Step 3:
  /// `(value as num?)?.toDouble() ?? 0.0` (see list [itemBuilder]).
  Widget _buildReviewListCard(
    BuildContext context,
    ArtistReview r, {
    required double rating,
    required double cleanliness,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final int ratingStars = rating.round().clamp(1, 5);
    final int cleanlinessStars = cleanliness.round().clamp(1, 5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFC107),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Rating',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFFC107),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TattooExperienceStarBar(
                      value: ratingStars,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const CleanHandsIcon(size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Cleanliness',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TattooCleanlinessStarBar(
                      value: cleanlinessStars,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          r.comment,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          _formatReviewDate(r.createdAt),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.outline,
              ),
        ),
      ],
    );
  }

  String _formatReviewDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
