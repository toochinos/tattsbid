import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/user_profile.dart';
import '../core/services/chat_service.dart';
import '../core/services/profile_service.dart';
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
  /// Other entry points use Stripe payment rules instead.
  final bool fromArtistsDirectory;

  @override
  State<PublicArtistProfilePage> createState() =>
      _PublicArtistProfilePageState();
}

class _PublicArtistProfilePageState extends State<PublicArtistProfilePage> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  /// Chat + email/phone only after customer has paid (completed request with this artist).
  bool _showContactAndChat = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await ProfileService.getProfileByUserId(widget.userId);
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
      setState(() {
        _profile = p;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const _FiveStarReviewTitle(),
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
}

/// Five filled yellow stars in the app bar (review-style), replacing “Bid winner”.
class _FiveStarReviewTitle extends StatelessWidget {
  const _FiveStarReviewTitle();

  static const Color _gold = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '5 out of 5 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          5,
          (_) => const Icon(
            Icons.star_rounded,
            color: _gold,
            size: 26,
          ),
        ),
      ),
    );
  }
}
