import 'package:flutter/material.dart';

import '../core/models/user_profile.dart';
import '../core/routes/app_routes.dart';
import '../core/services/profile_service.dart';
import '../core/utils/user_type_utils.dart';
import '../l10n/app_localizations.dart';
import '../widgets/user_name_with_role.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(l10n.tabProfile),
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
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
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
    final profile = _profile;
    if (profile == null) {
      return Center(child: Text(l10n.profileNotLoggedIn));
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
              UserNameWithRole(
                name: profile.displayNameOrEmail,
                userType: profile.userType,
                textAlign: TextAlign.center,
                nameStyle: Theme.of(context).textTheme.headlineSmall,
                roleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                maxNameLines: 2,
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
                label: Text(l10n.profileEditContact),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
