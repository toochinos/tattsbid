import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.paywall),
            child: const Text('Subscribe'),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.red),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
          ),
        ],
      ),
      body: const Center(child: Text('Dashboard Page')),
    );
  }
}
