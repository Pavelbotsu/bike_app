import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/ride_tracking_service.dart';
import '../services/ride_history_service.dart';
import '../theme/app_theme.dart';
import '../widgets/rounded_card.dart';
import 'post_ride_screen.dart';

class LiveRideScreen extends StatefulWidget {
  const LiveRideScreen({super.key});

  @override
  State<LiveRideScreen> createState() => _LiveRideScreenState();
}

class _LiveRideScreenState extends State<LiveRideScreen> {
  final RideTrackingService _trackingService = RideTrackingService();
  final MapController _mapController = MapController();
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  StreamSubscription<Position>? _positionSub;

  double _speedKmh = 0;
  double _distanceKm = 0;
  Duration _elapsed = Duration.zero;
  Position? _lastPosition;
  bool _paused = false;
  String? _error;
  DateTime? _startTime;
  List<LatLng> _routePoints = [];

  bool get _isIdle => _startTime == null;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startRide() async {
    try {
      await _trackingService.start();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      return;
    }

    setState(() => _startTime = DateTime.now());
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = _stopwatch.elapsed);
    });
    _positionSub = _trackingService.positionStream.listen(_onPosition);
  }

  void _onPosition(Position pos) {
    if (!mounted) return;
    final newPoint = LatLng(pos.latitude, pos.longitude);
    setState(() {
      if (_lastPosition != null) {
        _distanceKm += Geolocator.distanceBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              pos.latitude,
              pos.longitude,
            ) /
            1000;
      }
      _lastPosition = pos;
      _speedKmh = pos.speed * 3.6;
      _routePoints.add(newPoint);
    });
    try {
      _mapController.move(newPoint, 15);
    } catch (_) {}
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _stopwatch.stop();
      _positionSub?.cancel();
      _positionSub = null;
      _trackingService.pause();
    } else {
      _stopwatch.start();
      _trackingService.resume();
      _positionSub = _trackingService.positionStream.listen(_onPosition);
    }
  }

  Future<void> _stopRide() async {
    _timer?.cancel();
    _timer = null;
    _positionSub?.cancel();
    _positionSub = null;
    _stopwatch.stop();

    final startTime = _startTime!;
    final ride = _trackingService.finish(startTime);
    await RideHistoryService.instance.saveRide(ride);

    _stopwatch.reset();
    setState(() {
      _startTime = null;
      _speedKmh = 0;
      _distanceKm = 0;
      _elapsed = Duration.zero;
      _lastPosition = null;
      _paused = false;
      _routePoints = [];
    });

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostRideScreen(ride: ride)),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSub?.cancel();
    _trackingService.stop();
    super.dispose();
  }

  String _formatSpeed(double kmh) => kmh.toStringAsFixed(1);
  String _formatDist(double km) => '${km.toStringAsFixed(2)} km';
  String _formatClock(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _formatTime(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF090A0E), Color(0xFF0B1119)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: _isIdle ? _buildIdle() : _buildRiding(),
          ),
        ],
      ),
    );
  }

  Widget _buildIdle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Chip(label: 'READY', color: Color(0x1A9EA1B1)),
        const Spacer(),
        const Text(
          'VELOCITY',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap below to start tracking',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const Spacer(),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: _startRide,
          icon: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
          label: const Text(
            'START RIDE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRiding() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Chip(
              label: 'LIVE RIDE',
              color: AppColors.accent.withValues(alpha: 0.22),
            ),
            if (_startTime != null)
              _Chip(
                label: _paused
                    ? 'PAUSED'
                    : 'STARTED ${_formatClock(_startTime!)}',
                color: _paused
                    ? Colors.orange.withValues(alpha: 0.22)
                    : AppColors.highlight.withValues(alpha: 0.18),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _buildLiveMap(),
        const SizedBox(height: 14),
        if (_error != null)
          RoundedCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          )
        else ...[
          _SpeedCard(value: _formatSpeed(_speedKmh)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricBubble(
                  label: 'DISTANCE',
                  value: _formatDist(_distanceKm),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricBubble(
                  label: 'TIME',
                  value: _formatTime(_elapsed),
                ),
              ),
            ],
          ),
        ],
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF181C28),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _togglePause,
                icon: Icon(
                  _paused ? Icons.play_arrow : Icons.pause,
                  color: AppColors.textPrimary,
                ),
                label: Text(
                  _paused ? 'RESUME' : 'PAUSE',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _stopRide,
                icon: const Icon(Icons.stop, color: Colors.white),
                label: const Text(
                  'STOP',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLiveMap() {
    return SizedBox(
      height: 170,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _routePoints.isEmpty
                ? const LatLng(52.0, 19.0)
                : _routePoints.last,
            initialZoom: 15,
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.bike_app',
            ),
            if (_routePoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: AppColors.accent,
                    strokeWidth: 3,
                  ),
                ],
              ),
            if (_routePoints.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _routePoints.last,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SpeedCard extends StatelessWidget {
  final String value;

  const _SpeedCard({required this.value});

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'SPEED',
            style: TextStyle(
              color: AppColors.textSecondary,
              letterSpacing: 1.6,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              color: AppColors.accent,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'KM/H',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBubble extends StatelessWidget {
  final String label;
  final String value;

  const _MetricBubble({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              letterSpacing: 1.5,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
