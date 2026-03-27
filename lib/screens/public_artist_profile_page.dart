import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/artist_review.dart';
import '../core/models/user_profile.dart';
import '../core/services/chat_service.dart';
import '../core/services/profile_service.dart';
import '../core/services/review_service.dart';
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
  int _draftRating = 0;
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
            _draftRating == 0) {
          _reviewCommentController.text = mine.comment;
          _draftRating = mine.rating;
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
            _draftRating == 0) {
          _reviewCommentController.text = mine.comment;
          _draftRating = mine.rating;
        }
      });
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> _submitReview() async {
    final comment = _reviewCommentController.text.trim();
    if (_draftRating < 1 || _draftRating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating.')),
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
        comment: comment,
      );
      if (!mounted) return;
      _reviewCommentController.clear();
      setState(() {
        _draftRating = 0;
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
              Text(
                '${ReviewService.averageRating(_reviews).toStringAsFixed(1)} average',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Center(
                child: _ReviewStarRow(
                  rating:
                      ReviewService.averageRating(_reviews).round().clamp(1, 5),
                  size: 22,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ..._reviews.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ReviewStarRow(rating: r.rating, size: 18),
                    const SizedBox(height: 6),
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
                ),
              ),
            ),
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
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final value = i + 1;
                    final filled = value <= _draftRating;
                    return IconButton(
                      onPressed: _submittingReview
                          ? null
                          : () => setState(() => _draftRating = value),
                      icon: Icon(
                        Icons.star_rounded,
                        color: filled
                            ? const Color(0xFFFFC107)
                            : scheme.outline.withValues(alpha: 0.45),
                        size: 36,
                      ),
                    );
                  }),
                ),
              ),
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

  String _formatReviewDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

/// Non-interactive 1–5 star row for display.
class _ReviewStarRow extends StatelessWidget {
  const _ReviewStarRow({
    required this.rating,
    this.size = 20,
  });

  final int rating;
  final double size;

  static const Color _gold = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context) {
    final emptyColor =
        Theme.of(context).colorScheme.outline.withValues(alpha: 0.35);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          Icons.star_rounded,
          color: i < rating ? _gold : emptyColor,
          size: size,
        ),
      ),
    );
  }
}
