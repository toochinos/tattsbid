import 'package:flutter/material.dart';

import '../core/models/user_profile.dart';
import '../core/routes/app_routes.dart';
import '../core/services/profile_service.dart';
import '../core/utils/user_type_utils.dart';

/// Profile tab - shows user avatar, name, location, and Edit contact button.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.onProfileUpdated});

  /// Called after profile is reloaded (e.g. when returning from edit).
  final VoidCallback? onProfileUpdated;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ProfileService.getCurrentProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context, rootNavigator: true)
                .pushNamed(AppRoutes.settings),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadProfile,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final profile = _profile;
    if (profile == null) {
      return const Center(child: Text('Not logged in'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 56,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage: profile.avatarUrl != null &&
                        profile.avatarUrl!.trim().isNotEmpty
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null ||
                        profile.avatarUrl!.trim().isEmpty
                    ? Text(
                        profile.displayNameOrEmail.isNotEmpty
                            ? profile.displayNameOrEmail[0].toUpperCase()
                            : '?',
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                      )
                    : null,
              ),
              const SizedBox(height: 24),
              Text(
                profile.displayNameOrEmail,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (profile.location != null &&
                  profile.location!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on,
                        size: 18, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(width: 6),
                    Text(
                      profile.location!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ],
              if (profile.userType != null &&
                  profile.userType!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  profile.userType == 'tattoo_artist'
                      ? 'Tattoo Artist'
                      : 'Customer',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () async {
                  final p = _profile;
                  final allowPick = p != null && !profileHasSetAccountType(p);
                  await Navigator.of(context, rootNavigator: true).pushNamed(
                    AppRoutes.profile,
                    arguments: <String, dynamic>{
                      'fromSignUp': false,
                      'allowAccountTypeChoice': allowPick,
                    },
                  );
                  if (!mounted) return;
                  await _loadProfile();
                  widget.onProfileUpdated?.call();
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit contact'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
