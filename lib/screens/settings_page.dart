import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/locale/app_locale_controller.dart';
import '../core/navigation/link_handler.dart';
import '../core/routes/app_routes.dart';
import '../core/services/auth_service.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _languageDisplayName(AppLocalizations l10n, String code) {
    switch (code) {
      case 'km':
        return l10n.languageKhmer;
      case 'id':
        return l10n.languageIndonesian;
      default:
        return l10n.languageEnglish;
    }
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final controller = context.read<AppLocaleController>();
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final d = AppLocalizations.of(dialogContext)!;
        final scheme = Theme.of(dialogContext).colorScheme;
        final cur = controller.locale.languageCode;
        return AlertDialog(
          title: Text(d.languagePickerTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(d.languageEnglish),
                  trailing: cur == 'en'
                      ? Icon(Icons.check, color: scheme.primary)
                      : null,
                  onTap: () => Navigator.pop(dialogContext, 'en'),
                ),
                ListTile(
                  title: Text(d.languageKhmer),
                  trailing: cur == 'km'
                      ? Icon(Icons.check, color: scheme.primary)
                      : null,
                  onTap: () => Navigator.pop(dialogContext, 'km'),
                ),
                ListTile(
                  title: Text(d.languageIndonesian),
                  trailing: cur == 'id'
                      ? Icon(Icons.check, color: scheme.primary)
                      : null,
                  onTap: () => Navigator.pop(dialogContext, 'id'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                MaterialLocalizations.of(dialogContext).cancelButtonLabel,
              ),
            ),
          ],
        );
      },
    );
    if (!context.mounted || chosen == null) return;
    await controller.setLanguage(chosen);
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.landing);
  }

  Future<void> _confirmDeleteAccount() async {
    final supabase = Supabase.instance.client;

    final session = supabase.auth.currentSession;

    if (session == null) {
      debugPrint('delete-user: no session');
      return;
    }

    try {
      await supabase.auth.refreshSession();
      if (supabase.auth.currentSession == null) {
        debugPrint('delete-user: no session after refresh');
        return;
      }

      // Do not set Authorization manually: AuthHttpClient uses putIfAbsent, so a
      // hand-set Bearer token blocks automatic refresh and can produce stale JWTs.
      // The SDK attaches the current session JWT (and refreshes when needed).

      // 1) Edge function deletes user while JWT is still valid
      final response = await supabase.functions.invoke('delete-user');

      if (response.status != 200) {
        if (!mounted) return;
        var reason = 'HTTP ${response.status}';
        final data = response.data;
        if (data is Map && data['error'] != null) {
          reason = data['error'].toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.settingsAccountDeleteFailed(reason),
            ),
          ),
        );
        return;
      }

      // 2) THEN clear local session (only after successful delete)
      await AuthService.signOut();

      debugPrint('delete-user: account deleted');

      if (!mounted) return;
      LinkHandler.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final root = LinkHandler.navigatorKey.currentContext;
        if (root != null && root.mounted) {
          final msg = AppLocalizations.of(root)?.settingsAccountDeleted ??
              'Account deleted';
          ScaffoldMessenger.of(root).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      });
    } on FunctionException catch (e) {
      if (!mounted) return;
      final detail = e.details?.toString() ?? e.toString();
      if (detail.contains('Invalid JWT')) {
        debugPrint(
          'delete-user: Supabase gateway rejected the JWT. If this persists, '
          'deploy the function with verify_jwt disabled for this route (see '
          'supabase/config.toml [functions.delete-user] verify_jwt = false) '
          'then run: supabase functions deploy delete-user',
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.settingsAccountDeleteFailed(detail),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.settingsAccountDeleteFailed(
              e.toString(),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final localeController = context.watch<AppLocaleController>();
    final isDark = AppTheme.themeModeNotifier.value == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: isDark,
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            title: Text(
              isDark ? l10n.settingsDarkMode : l10n.settingsLightMode,
            ),
            subtitle: Text(l10n.settingsToggleTheme),
            onChanged: (enabled) {
              AppTheme.themeModeNotifier.value =
                  enabled ? ThemeMode.dark : ThemeMode.light;
              setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.settingsLanguage),
            subtitle: Text(l10n.settingsLanguageSubtitle),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _languageDisplayName(
                    l10n,
                    localeController.locale.languageCode,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
            onTap: () => _pickLanguage(context),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.settingsSignOut),
            onTap: () => _logout(context),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              l10n.settingsDangerZone,
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
            child: Text(
              l10n.settingsDeleteAccount,
              style: const TextStyle(color: Colors.white),
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
                    l10n.appVersionLabel('2.0.2'),
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
