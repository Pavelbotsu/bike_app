import 'package:flutter/material.dart';
import '../models/ride.dart';
import '../services/ride_history_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/rounded_card.dart';
import 'post_ride_screen.dart';

/// Activities / history management panel: lifetime summary, search, rides
/// grouped by recency, swipe-to-delete and rename.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Ride> _rides = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadRides();
    RideHistoryService.instance.addListener(_loadRides);
  }

  @override
  void dispose() {
    RideHistoryService.instance.removeListener(_loadRides);
    super.dispose();
  }

  Future<void> _loadRides() async {
    final rides = await RideHistoryService.instance.loadRides();
    if (mounted) {
      setState(() {
        _rides = rides;
        _loading = false;
      });
    }
  }

  List<Ride> get _filtered {
    if (_query.trim().isEmpty) return _rides;
    final q = _query.toLowerCase();
    return _rides.where((r) {
      return r.displayName.toLowerCase().contains(q) ||
          _fmtDate(r.startTime).toLowerCase().contains(q);
    }).toList();
  }

  double get _totalKm => _rides.fold(0.0, (s, r) => s + r.distanceKm);
  Duration get _totalTime =>
      _rides.fold(Duration.zero, (s, r) => s + r.duration);
  double get _totalElevation =>
      _rides.fold(0.0, (s, r) => s + r.elevationGainM);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ACTIVITIES',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            _buildSummary(),
            const SizedBox(height: 16),
            if (_rides.isNotEmpty) _buildSearch(),
            const SizedBox(height: 8),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return RoundedCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
                label: 'TOTAL', value: '${fmtDistance(_totalKm)} km'),
          ),
          Expanded(
            child: _SummaryItem(
                label: 'RIDES', value: _rides.length.toString()),
          ),
          Expanded(
            child:
                _SummaryItem(label: 'TIME', value: fmtDuration(_totalTime)),
          ),
          Expanded(
            child: _SummaryItem(
              label: 'CLIMB',
              value: '${fmtElevation(_totalElevation)} m',
              color: AppColors.highlight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      onChanged: (v) => setState(() => _query = v),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search rides',
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon:
            const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_rides.isEmpty) {
      return _emptyState(
        title: 'No rides recorded yet',
        subtitle: 'Tap the record button to start your first ride',
      );
    }

    final filtered = _filtered;
    if (filtered.isEmpty) {
      return _emptyState(
        title: 'No matches',
        subtitle: 'Try a different search',
      );
    }

    final sections = _groupBySection(filtered);
    final children = <Widget>[];
    for (final entry in sections.entries) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8, left: 4),
        child: Text(
          entry.key,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ));
      for (final ride in entry.value) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildDismissibleTile(ride),
        ));
      }
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      children: children,
    );
  }

  Widget _buildDismissibleTile(Ride ride) {
    return Dismissible(
      key: ValueKey(ride.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(ride),
      onDismissed: (_) async {
        setState(() => _rides.removeWhere((r) => r.id == ride.id));
        await RideHistoryService.instance.deleteRide(ride.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFB71C1C).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: _RideTile(
        ride: ride,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostRideScreen(ride: ride)),
        ),
        onRename: () => _renameRide(ride),
      ),
    );
  }

  Future<bool> _confirmDelete(Ride ride) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete ride?'),
        content: Text(
          'Permanently delete "${ride.displayName}"? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _renameRide(Ride ride) async {
    final controller = TextEditingController(text: ride.displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rename ride'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Ride name',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2A2D3E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('SAVE',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await RideHistoryService.instance.renameRide(ride.id, newName);
    }
  }

  Widget _emptyState({required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_bike,
              size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Groups rides into Today / This Week / "Month Year" sections, preserving
  /// the newest-first ordering from the database.
  Map<String, List<Ride>> _groupBySection(List<Ride> rides) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final result = <String, List<Ride>>{};

    for (final ride in rides) {
      final d = ride.startTime;
      final day = DateTime(d.year, d.month, d.day);
      String key;
      if (day == today) {
        key = 'TODAY';
      } else if (day.isAfter(weekAgo)) {
        key = 'THIS WEEK';
      } else {
        key = '${_monthName(d.month)} ${d.year}'.toUpperCase();
      }
      result.putIfAbsent(key, () => []).add(ride);
    }
    return result;
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _monthName(int m) => _months[m - 1];

  String _fmtDate(DateTime dt) => '${_monthName(dt.month)} ${dt.day}, ${dt.year}';
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    this.color = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RideTile extends StatelessWidget {
  final Ride ride;
  final VoidCallback onTap;
  final VoidCallback onRename;

  const _RideTile({
    required this.ride,
    required this.onTap,
    required this.onRename,
  });

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime dt) =>
      '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onRename,
      child: RoundedCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.directions_bike,
                  color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ride.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_fmtDate(ride.startTime)}  ·  ${fmtDistance(ride.distanceKm)} km  ·  ${fmtDuration(ride.duration)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmtSpeed(ride.avgMovingSpeedKmh),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
                const Text(
                  'km/h avg',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
