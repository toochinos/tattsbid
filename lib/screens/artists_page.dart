import 'package:flutter/material.dart';

import '../core/models/artist_directory_entry.dart';
import '../core/services/profile_service.dart';
import '../core/services/review_service.dart';
import '../widgets/clean_hands_icon.dart';
import 'public_artist_profile_page.dart';

/// Browse tattoo artists (directory + search).
class ArtistsPage extends StatefulWidget {
  const ArtistsPage({super.key});

  @override
  State<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage> {
  final TextEditingController _searchController = TextEditingController();

  List<ArtistDirectoryEntry> _all = [];

  /// Separate means from `reviews` (rating + cleanliness), keyed by artist id.
  Map<String, ArtistDualRatingAverages> _reviewAverages = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ProfileService.fetchTattooArtistsForDirectory();
      var averages = <String, ArtistDualRatingAverages>{};
      try {
        averages = await ReviewService.fetchDualAveragesForArtistIds(
          list.map((a) => a.id),
        );
      } catch (_) {
        // RLS or offline — still show directory with profile.rating if any
      }
      if (!mounted) return;
      setState(() {
        _all = list;
        _reviewAverages = averages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<ArtistDirectoryEntry> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((a) {
      final nameMatch = a.displayName.toLowerCase().contains(q);
      final loc = (a.location ?? '').toLowerCase();
      final locationMatch = loc.contains(q);
      return nameMatch || locationMatch;
    }).toList();
  }

  void _openProfile(ArtistDirectoryEntry artist) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PublicArtistProfilePage(
          userId: artist.id,
          fromArtistsDirectory: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Artists'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search artist or location',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.trim().isNotEmpty
                    ? IconButton(
                        onPressed: () => _searchController.clear(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear search',
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: _buildBody(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_search,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                _all.isEmpty
                    ? 'No artists found yet'
                    : 'No artists match your search',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _all.isEmpty
                    ? 'Check back when tattoo artists join the platform.'
                    : 'Try a different name or location.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
        itemCount: list.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
                alpha: 0.5,
              ),
        ),
        itemBuilder: (context, index) {
          final artist = list[index];
          final hasLocation =
              artist.location != null && artist.location!.trim().isNotEmpty;
          final dual = _reviewAverages[artist.id];
          final expMean = dual?.experienceMean ?? artist.rating ?? 0;
          final cleanMean = dual?.cleanlinessMean ?? 0;
          final hasRating = expMean > 0 || cleanMean > 0;
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: artist.avatarUrl != null &&
                      artist.avatarUrl!.trim().isNotEmpty
                  ? NetworkImage(artist.avatarUrl!.trim())
                  : null,
              child: artist.avatarUrl == null ||
                      artist.avatarUrl!.trim().isEmpty
                  ? Text(
                      artist.displayName.isNotEmpty
                          ? artist.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            title: Text(
              artist.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: (!hasLocation && !hasRating)
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasLocation)
                          Text(
                            artist.location!.trim(),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (hasRating)
                          Padding(
                            padding: EdgeInsets.only(
                              top: hasLocation ? 6 : 0,
                            ),
                            child: _DirectoryDualRatingLines(
                              experienceAverage: expMean,
                              cleanlinessAverage: cleanMean,
                            ),
                          ),
                      ],
                    ),
                  ),
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.outline,
            ),
            onTap: () => _openProfile(artist),
          );
        },
      ),
    );
  }
}

/// Compact dual lines for directory list (no combined score).
class _DirectoryDualRatingLines extends StatelessWidget {
  const _DirectoryDualRatingLines({
    required this.experienceAverage,
    required this.cleanlinessAverage,
  });

  final double experienceAverage;
  final double cleanlinessAverage;

  static const Color _gold = Color(0xFFFFC107);
  static const Color _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final empty = Theme.of(context).colorScheme.outline.withValues(alpha: 0.35);
    final bodySmall = Theme.of(context).textTheme.bodySmall;

    Widget line({
      required Widget leading,
      required Color starColor,
      required String label,
      required double average,
    }) {
      if (average <= 0) return const SizedBox.shrink();
      final filled = average.round().clamp(1, 5);
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 4),
            Text(
              '$label: ',
              style: bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: starColor,
              ),
            ),
            ...List.generate(
              5,
              (i) => Icon(
                Icons.star_rounded,
                size: 14,
                color: i < filled ? starColor : empty,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              average.toStringAsFixed(1),
              style: bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line(
          leading: Icon(Icons.star_rounded, size: 16, color: _gold),
          starColor: _gold,
          label: 'Rating',
          average: experienceAverage,
        ),
        line(
          leading: const CleanHandsIcon(size: 14),
          starColor: _green,
          label: 'Cleanliness',
          average: cleanlinessAverage,
        ),
      ],
    );
  }
}
