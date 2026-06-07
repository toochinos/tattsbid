import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/supabase_config.dart';
import '../core/models/developer_dashboard.dart';
import '../core/services/developer_dashboard_service.dart';
import '../core/services/online_presence_service.dart';

/// Developer stats via `get_dashboard_stats()` (after hidden password in Settings).
class DeveloperDashboardPage extends StatefulWidget {
  const DeveloperDashboardPage({super.key});

  @override
  State<DeveloperDashboardPage> createState() => _DeveloperDashboardPageState();
}

class _DeveloperDashboardPageState extends State<DeveloperDashboardPage>
    with SingleTickerProviderStateMixin {
  DeveloperDashboard _data = DeveloperDashboard.empty;
  bool _loading = true;
  bool _hasLoadedOnce = false;
  bool _loadInFlight = false;

  /// Invalidates async [_load] completions after [dispose].
  int _loadGeneration = 0;
  Timer? _refreshTimer;
  late final AnimationController _refreshSpinController;

  @override
  void initState() {
    super.initState();
    _refreshSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _loadInFlight) return;
      _refreshPresenceCounts();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshSpinController.dispose();
    _loadGeneration++;
    super.dispose();
  }

  void _setRefreshSpinning(bool spinning) {
    if (spinning) {
      if (!_refreshSpinController.isAnimating) {
        _refreshSpinController.repeat();
      }
    } else {
      _refreshSpinController.stop();
      _refreshSpinController.reset();
    }
  }

  /// JS: `setOnlineUsers(onlineCount)` — filtered 60s count, not raw RPC value.
  Future<void> _refreshPresenceCounts() async {
    if (!mounted || _loadInFlight || !_hasLoadedOnce) return;

    try {
      if (!isSupabaseReady()) return;

      final onlineCount = await OnlinePresenceService.computeOnlineCount();
      if (!mounted) return;

      debugPrint('DeveloperDashboard setOnlineUsers: onlineCount=$onlineCount');

      setState(() {
        _data = _data.copyWith(onlineUsers: onlineCount);
      });
    } catch (e, stack) {
      debugPrint('Developer dashboard presence refresh: $e');
      debugPrint('$stack');
    }
  }

  Future<void> _load() async {
    if (!mounted || _loadInFlight) return;

    final generation = ++_loadGeneration;
    _loadInFlight = true;
    _setRefreshSpinning(true);

    final isRefresh = _hasLoadedOnce;
    if (isRefresh) {
      _setStateIfActive(generation, () => _loading = true);
    }

    try {
      if (!isSupabaseReady()) {
        debugPrint('Developer dashboard: Supabase not ready');
        if (_shouldApplyLoad(generation)) {
          _setStateIfActive(generation, () => _loading = false);
        }
        return;
      }

      final dashboard = await DeveloperDashboardService.fetchDashboard();
      if (!_shouldApplyLoad(generation)) return;

      debugPrint(
        'DeveloperDashboard setState: onlineUsers=${dashboard.onlineUsers} '
        'activeUsersToday=${dashboard.activeUsersToday}',
      );

      _setStateIfActive(generation, () {
        _data = dashboard;
        _hasLoadedOnce = true;
        _loading = false;
      });
    } catch (e, stack) {
      debugPrint('Dashboard error: $e');
      debugPrint('$stack');
      if (!_shouldApplyLoad(generation)) return;

      _setStateIfActive(generation, () => _loading = false);

      if (_hasLoadedOnce && mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Unable to refresh dashboard')),
        );
      }
    } finally {
      if (_loadGeneration == generation) {
        _loadInFlight = false;
        _setRefreshSpinning(false);
        if (mounted) setState(() {});
      }
    }
  }

  bool _shouldApplyLoad(int generation) {
    return mounted && _loadGeneration == generation;
  }

  void _setStateIfActive(int generation, VoidCallback fn) {
    if (!_shouldApplyLoad(generation)) return;
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Dashboard'),
        actions: [
          IconButton(
            onPressed: _loadInFlight ? null : _load,
            tooltip: 'Refresh',
            icon: RotationTransition(
              turns: _refreshSpinController,
              child: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading && _hasLoadedOnce)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _DashboardBody(
                data: _data,
                showSkeleton: _loading && !_hasLoadedOnce,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single scrollable body — avoids swapping widgets under [RefreshIndicator].
class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.data,
    required this.showSkeleton,
  });

  final DeveloperDashboard data;
  final bool showSkeleton;

  @override
  Widget build(BuildContext context) {
    if (showSkeleton) {
      return const _DashboardSkeletonList();
    }
    return _DashboardStatsList(data: data);
  }
}

class _DashboardStatsList extends StatelessWidget {
  const _DashboardStatsList({required this.data});

  final DeveloperDashboard data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const PageStorageKey<String>('developer_dashboard_stats_list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildLiveTile(
          title: 'Online Users',
          value: data.onlineUsers,
        ),
        _buildStatTile(
          context: context,
          icon: Icons.people,
          title: 'Active Users Today',
          value: data.activeUsersToday,
        ),
        const Divider(height: 24),
        _buildStatTile(
          context: context,
          icon: Icons.person,
          title: 'Total Users',
          value: data.totalUsers,
        ),
        _buildStatTile(
          context: context,
          icon: Icons.person_outline,
          title: 'Customers',
          value: data.totalCustomers,
        ),
        _buildStatTile(
          context: context,
          icon: Icons.brush,
          title: 'Tattoo Artists',
          value: data.totalArtists,
        ),
        _buildStatTile(
          context: context,
          icon: Icons.person_add,
          title: 'New Users This Week',
          value: data.newUsersThisWeek,
        ),
        _buildStatTile(
          context: context,
          icon: Icons.image,
          title: 'Tattoo Requests',
          value: data.totalTattooRequests,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  static Widget _buildLiveTile({
    required String title,
    required int value,
  }) {
    return ListTile(
      leading: Icon(
        Icons.circle,
        color: value > 0 ? Colors.green : Colors.grey,
        size: 14,
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: Text(
        '$value',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static Widget _buildStatTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int value,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      trailing: Text(
        '$value',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DashboardSkeletonList extends StatelessWidget {
  const _DashboardSkeletonList();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView(
      key: const PageStorageKey<String>('developer_dashboard_skeleton_list'),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: List.generate(7, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 40,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
