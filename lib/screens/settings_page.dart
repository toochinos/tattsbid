import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/routes/app_routes.dart';
import '../core/services/auth_service.dart';
import 'camera_page.dart';

Future<void> openCamera(BuildContext context) async {
  final status = await Permission.camera.request();

  if (!status.isGranted) {
    print("Camera permission denied");
    return;
  }
  if (!context.mounted) return;

  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CameraPage()),
  );
}

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
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton(
            onPressed: () {
              openCamera(context);
            },
            child: const Text("Open Camera"),
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
