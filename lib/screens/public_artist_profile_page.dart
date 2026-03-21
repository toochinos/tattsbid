import 'package:flutter/material.dart';

import '../core/models/user_profile.dart';
import '../core/services/profile_service.dart';

/// Read-only profile for another user (e.g. tattoo artist after winning a bid).
class PublicArtistProfilePage extends StatefulWidget {
  const PublicArtistProfilePage({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  State<PublicArtistProfilePage> createState() =>
      _PublicArtistProfilePageState();
}

class _PublicArtistProfilePageState extends State<PublicArtistProfilePage> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

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
      if (!mounted) return;
      setState(() {
        _profile = p;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bid winner'),
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
