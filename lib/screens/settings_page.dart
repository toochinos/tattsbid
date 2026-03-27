import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
    );
  }
}
