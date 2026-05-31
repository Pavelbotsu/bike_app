import 'package:flutter/material.dart';
import '../models/ride.dart';
import '../services/ride_history_service.dart';
import '../theme/app_theme.dart';
import '../widgets/rounded_card.dart';
import 'post_ride_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onStartRide;

  const HomeScreen({super.key, this.onStartRide});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Ride> _allRides = [];
  bool _loading = true;

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
        _allRides = rides;
        _loading = false;
      });
    }
  }

  List<Ride> get _todayRides {
    final now = DateTime.now();
    return _allRides
        .where((r) =>
            r.startTime.year == now.year &&
            r.startTime.month == now.month &&
            r.startTime.day == now.day)
        .toList();
  }

  Ride? get _lastRide => _allRides.isEmpty ? null : _allRides.first;

  double get _todayKm =>
      _todayRides.fold(0.0, (s, r) => s + r.distanceKm);

  Duration get _todayDuration =>
      _todayRides.fold(Duration.zero, (s, r) => s + r.duration);

  double get _todayElevation =>
      _todayRides.fold(0.0, (s, r) => s + r.elevationGainM);

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'GOOD MORNING'
        : hour < 17
            ? 'GOOD AFTERNOON'
            : 'GOOD EVENING';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(greeting),
            const SizedBox(height: 28),
            _buildTodayCard(),
            const SizedBox(height: 20),
            _buildStartButton(),
            if (!_loading && _lastRide != null && _todayRides.isEmpty) ...[
              const SizedBox(height: 20),
              _buildLastRideTile(_lastRide!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String greeting) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.surface,
          child: Icon(Icons.person, size: 28, color: AppColors.accent),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'VELOCITY',
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodayCard() {
    final hasData = _todayRides.isNotEmpty;
    final distStr = hasData
        ? '${_todayKm.toStringAsFixed(1)} km'
        : '--';
    final timeStr = hasData ? _fmtDuration(_todayDuration) : '--:--';
    final elevStr = hasData
        ? '${_todayElevation.toStringAsFixed(0)} m'
        : '--';

    return RoundedCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TODAY',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  letterSpacing: 1.8,
                ),
              ),
              if (hasData)
                Text(
                  '${_todayRides.length} ${_todayRides.length == 1 ? 'RIDE' : 'RIDES'}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _StatItem(label: 'DISTANCE', value: distStr)),
              Expanded(child: _StatItem(label: 'TIME', value: timeStr)),
              Expanded(child: _StatItem(label: 'ELEVATION', value: elevStr)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        onPressed: widget.onStartRide,
        icon: const Icon(Icons.play_arrow, size: 24),
        label: const Text('START RIDE'),
      ),
    );
  }

  Widget _buildLastRideTile(Ride ride) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final date =
        '${months[ride.startTime.month - 1]} ${ride.startTime.day}';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PostRideScreen(ride: ride)),
      ),
      child: RoundedCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.directions_bike,
                  color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LAST RIDE',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$date  ·  ${ride.distanceKm.toStringAsFixed(1)} km  ·  ${_fmtDuration(ride.duration)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
