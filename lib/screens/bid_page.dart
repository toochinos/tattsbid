import 'package:flutter/material.dart';

/// Legacy bid hub placeholder — not used in the bottom nav; bidding lives in
/// [BidDetailPage] from Explore. Kept so existing bid-related code can be reused.
class BidPage extends StatelessWidget {
  const BidPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bid')),
      body: const Center(child: Text('Bid')),
    );
  }
}
