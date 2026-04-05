import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/navigation/link_handler.dart';
import '../core/routes/app_routes.dart';
import '../core/services/auth_service.dart';
import '../core/theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _logout(BuildContext context) async {
    await AuthService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.landing);
  }

  Future<void> _confirmDeleteAccount() async {
    final supabase = Supabase.instance.client;

    final session = supabase.auth.currentSession;

    if (session == null) {
      print('❌ No session — user already logged out');
      return;
    }

    try {
      await supabase.auth.refreshSession();
      if (supabase.auth.currentSession == null) {
        print('❌ No session after refresh');
        return;
      }

      // Do not set Authorization manually: AuthHttpClient uses putIfAbsent, so a
      // hand-set Bearer token blocks automatic refresh and can produce stale JWTs.
      // The SDK attaches the current session JWT (and refreshes when needed).

      // 1) Edge function deletes user while JWT is still valid
      final response = await supabase.functions.invoke('delete-user');

      if (response.status != 200) {
        print('❌ Delete failed: ${response.status}');
        return;
      }

      // 2) THEN clear local session (only after successful delete)
      await AuthService.signOut();

      print('✅ Account deleted');

      if (!mounted) return;
      LinkHandler.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final root = LinkHandler.navigatorKey.currentContext;
        if (root != null && root.mounted) {
          ScaffoldMessenger.of(root).showSnackBar(
            const SnackBar(content: Text('Account deleted')),
          );
        }
      });
    } on FunctionException catch (e) {
      print('Delete error: $e');
      final detail = e.details?.toString() ?? '';
      if (detail.contains('Invalid JWT')) {
        debugPrint(
          'delete-user: Supabase gateway rejected the JWT. If this persists, '
          'deploy the function with verify_jwt disabled for this route (see '
          'supabase/config.toml [functions.delete-user] verify_jwt = false) '
          'then run: supabase functions deploy delete-user',
        );
      }
    } catch (e) {
      print('Delete error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = AppTheme.themeModeNotifier.value == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: isDark,
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            title: Text(isDark ? 'Dark mode' : 'Light mode'),
            subtitle: const Text('Toggle app theme'),
            onChanged: (enabled) {
              AppTheme.themeModeNotifier.value =
                  enabled ? ThemeMode.dark : ThemeMode.light;
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => _logout(context),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Danger zone',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () async {
              await _confirmDeleteAccount();
            },
            child: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      children: [
                        TextSpan(
                          text: 'TattsBid ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const TextSpan(text: '\u00A9 2026'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version 2.0.0',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
