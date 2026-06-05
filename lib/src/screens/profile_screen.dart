import 'package:flutter/material.dart';
import '../models/ride.dart';
import '../services/ride_history_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/rounded_card.dart';
import 'post_ride_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Ride> _rides = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRides();
    RideHistoryService.instance.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    RideHistoryService.instance.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onHistoryChanged() => _loadRides();

  Future<void> _loadRides() async {
    final rides = await RideHistoryService.instance.loadRides();
    if (mounted) {
      setState(() {
        _rides = rides;
        _loading = false;
      });
    }
  }

  double get _totalKm =>
      _rides.fold(0.0, (sum, r) => sum + r.distanceKm);

  double get _totalElevationM =>
      _rides.fold(0.0, (sum, r) => sum + r.elevationGainM);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildLifetimeMetricsCard(),
            const SizedBox(height: 24),
            const Text(
              'RECENT ACTIVITY',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildHistory()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.accent,
          child: Icon(Icons.person, size: 32, color: AppColors.background),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Text(
            'RIDER',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined,
              color: AppColors.textSecondary),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildLifetimeMetricsCard() {
    final km = _totalKm;
    return RoundedCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIFETIME METRICS',
            style: TextStyle(
              color: AppColors.textSecondary,
              letterSpacing: 1.8,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            fmtDistance(km),
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'KM',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          _MetricRow(
            label: 'RIDES COMPLETED',
            value: _rides.length.toString(),
          ),
          const SizedBox(height: 14),
          _MetricRow(
            label: 'ELEVATION GAIN',
            value: '${fmtElevation(_totalElevationM)} m',
            valueColor: AppColors.highlight,
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.directions_bike,
                size: 48, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text(
              'No rides recorded yet',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start a ride to see your history here',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final recent = _rides.take(5).toList();
    return ListView.separated(
      itemCount: recent.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _RideTile(
        ride: recent[i],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostRideScreen(ride: recent[i]),
          ),
        ),
      ),
    );
  }
}

class _RideTile extends StatelessWidget {
  final Ride ride;
  final VoidCallback onTap;

  const _RideTile({required this.ride, required this.onTap});

  String _fmtDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: RoundedCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.directions_bike,
                color: AppColors.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ride.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
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
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _MetricRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w700, color: valueColor),
        ),
      ],
    );
  }
}
