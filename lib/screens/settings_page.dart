import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/locale/app_locale_controller.dart';
import '../core/routes/app_routes.dart';
import '../core/services/auth_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/developer_login_dialog.dart';
import '../l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const int _developerTapTarget = 5;
  static const Duration _developerTapResetDelay = Duration(seconds: 2);

  int _developerTapCount = 0;
  Timer? _developerTapResetTimer;
  bool _developerGateInProgress = false;

  @override
  void dispose() {
    _developerTapResetTimer?.cancel();
    super.dispose();
  }

  void _onDeveloperModeTap() {
    if (_developerGateInProgress) return;
    _developerTapResetTimer?.cancel();
    _developerTapCount++;
    if (_developerTapCount >= _developerTapTarget) {
      _developerTapCount = 0;
      _openDeveloperGate();
      return;
    }
    _developerTapResetTimer = Timer(_developerTapResetDelay, () {
      if (mounted) setState(() => _developerTapCount = 0);
    });
    setState(() {});
  }

  Future<void> _openDeveloperGate() async {
    if (_developerGateInProgress || !mounted) return;
    _developerGateInProgress = true;
    try {
      final result = await DeveloperLoginDialog.prompt(context);
      if (!mounted) return;

      switch (result) {
        case DeveloperLoginResult.cancelled:
          return;
        case DeveloperLoginResult.wrongPassword:
          if (!mounted) return;
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(content: Text('Incorrect password')),
          );
          return;
        case DeveloperLoginResult.success:
          _developerTapResetTimer?.cancel();
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            debugPrint('Developer login: navigating to dashboard');
            unawaited(
              Navigator.of(context, rootNavigator: true).pushNamed(
                AppRoutes.developerDashboard,
              ),
            );
          });
      }
    } finally {
      if (mounted) {
        _developerGateInProgress = false;
      }
    }
  }

  Future<void> _openSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'admin@tattsbid.com',
    );
    await launchUrl(uri);
  }

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
    await AuthService.signOutAndLeaveApp();
  }

  Future<void> _confirmDeleteAccount() async {
    if (!mounted) return;
    await Navigator.of(context).pushNamed(AppRoutes.deleteAccount);
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
                  GestureDetector(
                    onTap: _onDeveloperModeTap,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text.rich(
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
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _openSupportEmail,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'admin@tattsbid.com',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.appVersionLabel('2.0.7 (7)'),
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
