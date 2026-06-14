import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/navigation/shell_chrome.dart';
import '../core/models/artist_review.dart';
import '../core/models/user_profile.dart';
import '../core/services/chat_service.dart';
import '../core/services/profile_service.dart';
import '../core/services/review_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/clean_hands_icon.dart';
import '../widgets/tattoo_review_rating_widgets.dart';
import 'chat_page.dart';
import '../widgets/safe_media_renderer.dart';
import '../widgets/user_name_with_role.dart';

/// Read-only profile for another user (e.g. opened from Artists directory).
/// Product copy may refer to this screen as the artist profile page.
class PublicArtistProfilePage extends StatefulWidget {
  static const String routeName = '/public-artist-profile';

  const PublicArtistProfilePage({
    super.key,
    required this.userId,
    this.fromArtistsDirectory = false,
  });

  final String userId;

  /// When true (Artists tab list → profile), email/phone in the Contact block are hidden
  /// (browse-only). The “Chat with Artist” button above Reviews still opens [ChatPage].
  /// When false, chat is available without a deposit payment.
  final bool fromArtistsDirectory;

  static bool isPublicProfileRoute(Route<dynamic> route) {
    return route.settings.name == routeName;
  }

  static MaterialPageRoute<void> materialRoute({
    required String userId,
    bool fromArtistsDirectory = false,
  }) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => PublicArtistProfilePage(
        userId: userId,
        fromArtistsDirectory: fromArtistsDirectory,
      ),
    );
  }

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

  /// Email/phone in Contact section (gated). Chat CTA above Reviews is always shown for artists.
  bool _showContactAndChat = true;

  @override
  void initState() {
    super.initState();
    ShellChrome.pushHideGlobalTopActions();
    _load();
  }

  @override
  void dispose() {
    ShellChrome.popHideGlobalTopActions();
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
        if (uid != null && uid != widget.userId) {
          allowContact = true;
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

  static String? _trimNonEmpty(String? s) {
    final t = s?.trim();
    return (t != null && t.isNotEmpty) ? t : null;
  }

  /// Suburb, city, then country (country bold). Falls back to legacy [location] only.
  Widget _buildLocationLine(BuildContext context, UserProfile profile) {
    final scheme = Theme.of(context).colorScheme;
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.outline,
        );
    final boldCountryStyle = baseStyle?.copyWith(fontWeight: FontWeight.w700);

    final suburb = _trimNonEmpty(profile.suburb);
    final city = _trimNonEmpty(profile.city);
    final country = _trimNonEmpty(profile.country);
    final legacy = _trimNonEmpty(profile.location);

    final hasStructured = suburb != null || city != null || country != null;
    if (!hasStructured && legacy == null) {
      return const SizedBox.shrink();
    }

    if (!hasStructured) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on, size: 18, color: scheme.outline),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              legacy!,
              style: baseStyle,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final spans = <InlineSpan>[];
    var first = true;
    void addSegment(String text, {required bool countryBold}) {
      if (!first) {
        spans.add(TextSpan(text: ', ', style: baseStyle));
      }
      first = false;
      spans.add(
        TextSpan(
          text: text,
          style: countryBold ? boldCountryStyle : baseStyle,
        ),
      );
    }

    if (suburb != null) addSegment(suburb, countryBold: false);
    if (city != null) addSegment(city, countryBold: false);
    if (country != null) addSegment(country, countryBold: true);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.location_on, size: 18, color: scheme.outline),
        const SizedBox(width: 6),
        Flexible(
          child: Text.rich(
            TextSpan(children: spans),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Public location line(s) when suburb/city/country/legacy is set. Role is under
  /// the name in the app bar.
  Widget _buildNameRoleLocationRow(
    BuildContext context,
    UserProfile profile,
    ColorScheme scheme,
  ) {
    final suburb = _trimNonEmpty(profile.suburb);
    final city = _trimNonEmpty(profile.city);
    final country = _trimNonEmpty(profile.country);
    final legacy = _trimNonEmpty(profile.location);
    final hasLoc =
        suburb != null || city != null || country != null || legacy != null;
    if (!hasLoc) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildLocationLine(context, profile),
        ),
      ],
    );
  }

  bool get _isOwnProfile {
    final me = Supabase.instance.client.auth.currentUser?.id;
    return me != null && me == widget.userId;
  }

  bool _canStartPrivateChat(UserProfile profile) {
    if (_isOwnProfile) return false;
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return false;
    final targetId = profile.id.trim();
    return targetId.isNotEmpty && targetId != me.id;
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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.publicProfileCantChatSelf)),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(initialReceiverId: widget.userId),
      ),
    );
  }

  String _appBarTitle(AppLocalizations l10n) {
    if (_loading) return l10n.publicProfileTitleFallback;
    final p = _profile;
    if (p == null) return l10n.publicProfileTitleFallback;
    final n = p.displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return l10n.publicProfileTitleFallback;
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
    final l10n = AppLocalizations.of(context)!;
    final comment = _reviewCommentController.text.trim();
    if (_draftRating < 1 ||
        _draftRating > 5 ||
        _draftCleanliness < 1 ||
        _draftCleanliness > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.publicProfileReviewSelectBoth),
        ),
      );
      return;
    }
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.publicProfileReviewCommentRequired)),
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
        ReviewSubmitResult.created => l10n.publicProfileReviewPostedThanks,
        ReviewSubmitResult.updated => l10n.publicProfileReviewUpdated,
        ReviewSubmitResult.alreadyReviewed =>
          l10n.publicProfileReviewAlreadyReviewedShort,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submittingReview = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.publicProfileReviewSubmitError),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: _loading || _profile == null
            ? Text(l10n.publicProfileTitleFallback)
            : UserNameWithRole(
                name: _appBarTitle(l10n),
                userType: _profile?.userType,
                nameStyle: Theme.of(context).appBarTheme.titleTextStyle ??
                    Theme.of(context).textTheme.titleLarge,
                roleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
                maxNameLines: 1,
              ),
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
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(context, _profile!, l10n),
    );
  }

  Widget _buildContent(
    BuildContext context,
    UserProfile profile,
    AppLocalizations l10n,
  ) {
    final name = profile.displayName?.trim().isNotEmpty == true
        ? profile.displayName!
        : l10n.bidDetailArtistNameFallback;
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
          _buildNameRoleLocationRow(context, profile, scheme),
          if (_canStartPrivateChat(profile)) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openChat,
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(l10n.publicProfileChatButton),
            ),
          ],
          if (profile.userType == 'tattoo_artist') ...[
            const SizedBox(height: 20),
            const SizedBox(height: 4),
            Text(
              l10n.publicProfileReviewsHeading,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
            ),
            const SizedBox(height: 12),
            if (_reviews.isEmpty)
              Text(
                l10n.publicProfileNoReviewsYet,
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
                  child: ExpansionTile(
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
                      l10n.publicProfilePreviousReviews,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    subtitle: Text(
                      l10n.publicProfileReviewsTileSubtitle(_reviews.length),
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
                    ? l10n.publicProfileWriteReview
                    : l10n.publicProfileEditReview,
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
                  hintText: l10n.publicProfileReviewHint,
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
                    : Text(l10n.publicProfileSubmitReview),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              l10n.profilePortfolioTitle,
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
                    child: SafeMediaRenderer(url: url),
                  );
                },
              ),
            ],
          ],
          if (profile.userType == 'tattoo_artist' && _showContactAndChat) ...[
            const SizedBox(height: 32),
            Text(
              l10n.profileContactSectionTitle,
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
                title: Text(l10n.publicProfileEmailTitle),
                subtitle: SelectableText(profile.contactEmail!),
              ),
            if (profile.mobile != null && profile.mobile!.trim().isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined),
                title: Text(l10n.publicProfileMobileTitle),
                subtitle: SelectableText(profile.mobile!),
              ),
            if ((profile.contactEmail == null ||
                    profile.contactEmail!.trim().isEmpty) &&
                (profile.mobile == null || profile.mobile!.trim().isEmpty))
              Text(
                l10n.publicProfileNoContactOnFile,
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
