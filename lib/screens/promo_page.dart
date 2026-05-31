import 'package:flutter/material.dart';

import 'add_page.dart';

/// Tattoo artists post portfolio work to Explore (PROMO cards).
class PromoPage extends StatelessWidget {
  const PromoPage({
    super.key,
    required this.selectedExploreCountryNotifier,
    this.onRequestSubmitted,
  });

  /// Posts are tagged for this country (same as Explore filter).
  final ValueNotifier<String> selectedExploreCountryNotifier;

  /// Called after a promo is successfully submitted (e.g. switch to Explore).
  final VoidCallback? onRequestSubmitted;

  @override
  Widget build(BuildContext context) {
    return AddPage(
      selectedExploreCountryNotifier: selectedExploreCountryNotifier,
      onRequestSubmitted: onRequestSubmitted,
      isArtistPromo: true,
    );
  }
}
