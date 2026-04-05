import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models/artist_directory_entry.dart';
import '../core/models/user_profile.dart';
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

  /// When set (e.g. via Near me), results must also match this `location` ILIKE.
  String? _nearMeLocationFilter;

  List<ArtistDirectoryEntry> _all = [];

  /// Separate means from `reviews` (rating + cleanliness), keyed by artist id.
  Map<String, ArtistDualRatingAverages> _reviewAverages = {};
  bool _loading = true;
  String? _error;

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _loadInitial();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _fetchArtists(showPageLoading: false);
    });
  }

  Future<void> _loadInitial() => _fetchArtists(showPageLoading: true);

  /// Runs directory search immediately (keyboard search/enter) without waiting for debounce.
  void _commitSearch() {
    _searchDebounce?.cancel();
    FocusScope.of(context).unfocus();
    _fetchArtists(showPageLoading: false);
  }

  /// Loads artists from Supabase using optional text + optional Near me location filter.
  Future<void> _fetchArtists({required bool showPageLoading}) async {
    if (showPageLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final text = _searchController.text.trim();
      final list = await ProfileService.fetchArtistsForDirectory(
        textSearch: text.isEmpty ? null : text,
        locationFilter: _nearMeLocationFilter,
      );
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
        if (showPageLoading) _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (showPageLoading) _loading = false;
        _error = e.toString();
      });
    }
  }

  String? _savedLocationToken(UserProfile? p) {
    if (p == null) return null;
    final loc = p.location?.trim();
    if (loc != null && loc.isNotEmpty) return loc;
    final city = p.city?.trim();
    if (city != null && city.isNotEmpty) return city;
    final sub = p.suburb?.trim();
    if (sub != null && sub.isNotEmpty) return sub;
    return null;
  }

  Future<void> _onNearMePressed() async {
    final profile = await ProfileService.getCurrentProfile();
    final token = _savedLocationToken(profile);
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a location to your profile first (Profile → location).',
          ),
        ),
      );
      return;
    }
    setState(() {
      _nearMeLocationFilter = token;
      _searchController.text = token;
    });
    _searchDebounce?.cancel();
    await _fetchArtists(showPageLoading: false);
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searchController.clear();
      _nearMeLocationFilter = null;
    });
    _fetchArtists(showPageLoading: false);
  }

  void _openProfile(ArtistDirectoryEntry artist) {
    Navigator.of(context, rootNavigator: false).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PublicArtistProfilePage(
          userId: artist.id,
          fromArtistsDirectory: true,
        ),
      ),
    );
  }

  /// Suburb, city, country (country bold); falls back to legacy [ArtistDirectoryEntry.location].
  Widget _directoryLocationLine(ArtistDirectoryEntry artist) {
    final scheme = Theme.of(context).colorScheme;
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.outline,
        );
    final countryStyle = baseStyle?.copyWith(fontWeight: FontWeight.w700);

    final suburb = artist.suburb?.trim();
    final city = artist.city?.trim();
    final country = artist.country?.trim();
    final legacy = artist.location?.trim();
    final hasStructured = (suburb != null && suburb.isNotEmpty) ||
        (city != null && city.isNotEmpty) ||
        (country != null && country.isNotEmpty);

    if (!hasStructured && (legacy == null || legacy.isEmpty)) {
      return const SizedBox.shrink();
    }

    if (!hasStructured) {
      return Text(
        legacy!,
        style: baseStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = <InlineSpan>[];
    var first = true;
    void add(String text, {bool countryBold = false}) {
      if (!first) {
        spans.add(TextSpan(text: ', ', style: baseStyle));
      }
      first = false;
      spans.add(
        TextSpan(
          text: text,
          style: countryBold ? countryStyle : baseStyle,
        ),
      );
    }

    if (suburb != null && suburb.isNotEmpty) add(suburb);
    if (city != null && city.isNotEmpty) add(city);
    if (country != null && country.isNotEmpty) add(country, countryBold: true);

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final showClear = hasQuery || _nearMeLocationFilter != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Artists'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _commitSearch(),
              decoration: InputDecoration(
                hintText: 'Name, city, suburb, or country',
                prefixIcon: const Icon(Icons.search),
                // Keep suffix intrinsic-width only — no [Flexible] here or it steals
                // horizontal space from the editable text area beside the magnifying glass.
                suffixIcon: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _onNearMePressed,
                          icon: Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: scheme.primary,
                          ),
                          label: Text(
                            'Artist near me',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      if (showClear)
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Clear search',
                          onPressed: _clearSearch,
                        ),
                    ],
                  ),
                ),
                suffixIconConstraints: const BoxConstraints(
                  minHeight: 48,
                  minWidth: 48,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          if (_nearMeLocationFilter != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Showing artists in ${_nearMeLocationFilter!}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
          const SizedBox(height: 8),
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
                onPressed: _loadInitial,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final list = _all;
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
                _searchController.text.trim().isEmpty &&
                        _nearMeLocationFilter == null
                    ? 'No artists found yet'
                    : 'No artists match your search',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _searchController.text.trim().isEmpty &&
                        _nearMeLocationFilter == null
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
      onRefresh: () => _fetchArtists(showPageLoading: false),
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
          final hasLocation = artist.hasLocationDisplay;
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
                        if (hasLocation) _directoryLocationLine(artist),
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
