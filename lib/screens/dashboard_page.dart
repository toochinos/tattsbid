import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../l10n/app_localizations.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboardTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.paywall),
            child: Text(l10n.paywallSubscribeTitle),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.red),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
          ),
        ],
      ),
      body: Center(child: Text(l10n.dashboardPlaceholderBody)),
    );
  }
}
