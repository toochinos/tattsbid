import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class DestinationPage extends StatelessWidget {
  const DestinationPage({super.key});

  void _popCountry(BuildContext context, String country) {
    Navigator.of(context, rootNavigator: true).pop<String>(country);
  }

  Widget buildDestinationItem({
    required BuildContext context,
    required String name,
    required String imagePath,
    bool showComingSoon = true,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              imagePath,
              width: 28,
              height: 28,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                color: Colors.transparent,
                child: const Text(
                  '🏳️',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.72,
                    ),
              ),
            ),
          ),
          if (showComingSoon)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l10n.destinationComingSoon,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.destinationChooseTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _popCountry(context, 'Australia'),
              child: buildDestinationItem(
                context: context,
                name: 'Australia',
                imagePath: 'assets/flags/australia.png',
                showComingSoon: false,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _popCountry(context, 'Cambodia'),
              child: buildDestinationItem(
                context: context,
                name: 'Cambodia, Phnom Penh',
                imagePath: 'assets/flags/cambodia.png',
                showComingSoon: false,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _popCountry(context, 'Indonesia'),
              child: buildDestinationItem(
                context: context,
                name: 'Indonesia, Bali',
                imagePath: 'assets/flags/indonesia.png',
                showComingSoon: false,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.destinationComingSoon)),
                );
              },
              child: buildDestinationItem(
                context: context,
                name: 'Thailand, Bangkok',
                imagePath: 'assets/flags/thailand.png',
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.destinationComingSoon)),
                );
              },
              child: buildDestinationItem(
                context: context,
                name: 'Vietnam, Saigon',
                imagePath: 'assets/flags/vietnam.png',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
