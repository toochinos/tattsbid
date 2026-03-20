import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../core/services/auth_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.landing);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
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
