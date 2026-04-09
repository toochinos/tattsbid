import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Legacy bid hub placeholder — not used in the bottom nav; bidding lives in
/// [BidDetailPage] from Explore. Kept so existing bid-related code can be reused.
class BidPage extends StatelessWidget {
  const BidPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = l10n.bidPageTitle;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}
