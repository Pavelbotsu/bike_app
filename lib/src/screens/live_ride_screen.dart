import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/hud_config.dart';
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
  double _maxSpeedKmh = 0;
  double _elevationM = 0;
  Duration _elapsed = Duration.zero;
  Position? _lastPosition;
  bool _paused = false;
  String? _error;
  DateTime? _startTime;
  List<LatLng> _routePoints = [];

  List<HudConfig> _hudConfigs = [];
  int _hudIndex = 0;

  bool get _isIdle => _startTime == null;
  HudConfig get _activeHud =>
      _hudConfigs.isEmpty ? HudConfig.defaultConfig : _hudConfigs[_hudIndex];

  @override
  void initState() {
    super.initState();
    _loadHud();
    HudConfigService.instance.addListener(_loadHud);
  }

  Future<void> _loadHud() async {
    final configs = await HudConfigService.instance.loadAll();
    final idx = await HudConfigService.instance.getActiveIndex();
    if (mounted) {
      setState(() {
        _hudConfigs = configs;
        _hudIndex = idx.clamp(0, configs.length - 1);
      });
    }
  }

  Future<void> _startRide() async {
    try {
      await _trackingService.start();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      return;
    }

    WakelockPlus.enable();
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
      if (_speedKmh > _maxSpeedKmh) _maxSpeedKmh = _speedKmh;
      _elevationM = pos.altitude;
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

    WakelockPlus.disable();
    _stopwatch.reset();
    setState(() {
      _startTime = null;
      _speedKmh = 0;
      _maxSpeedKmh = 0;
      _distanceKm = 0;
      _elevationM = 0;
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
    HudConfigService.instance.removeListener(_loadHud);
    _timer?.cancel();
    _positionSub?.cancel();
    _trackingService.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  String _formatClock(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';


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
        const SizedBox(height: 10),
        _buildLiveMap(),
        const SizedBox(height: 10),
        if (_error != null)
          RoundedCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          )
        else
          _HudPanel(
            config: _activeHud,
            configs: _hudConfigs,
            activeIndex: _hudIndex,
            onPageChanged: (i) {
              setState(() => _hudIndex = i);
              HudConfigService.instance.setActiveIndex(i);
            },
            speedKmh: _speedKmh,
            distanceKm: _distanceKm,
            elapsed: _elapsed,
            maxSpeedKmh: _maxSpeedKmh,
            elevationM: _elevationM,
          ),
        const Flexible(child: SizedBox()),
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
      height: 150,
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

String _fmtMetric(
  HudMetric m, {
  required double speedKmh,
  required double distanceKm,
  required Duration elapsed,
  required double maxSpeedKmh,
  required double elevationM,
}) {
  switch (m) {
    case HudMetric.speed:
      return speedKmh.toStringAsFixed(1);
    case HudMetric.distance:
      return '${distanceKm.toStringAsFixed(2)} km';
    case HudMetric.time:
      final h = elapsed.inHours;
      final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
      final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
      return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
    case HudMetric.avgSpeed:
      if (elapsed.inSeconds == 0) return '0.0';
      return (distanceKm / elapsed.inSeconds * 3600).toStringAsFixed(1);
    case HudMetric.maxSpeed:
      return maxSpeedKmh.toStringAsFixed(1);
    case HudMetric.elevation:
      return '${elevationM.toStringAsFixed(0)} m';
  }
}

class _HudPanel extends StatefulWidget {
  final HudConfig config;
  final List<HudConfig> configs;
  final int activeIndex;
  final ValueChanged<int> onPageChanged;
  final double speedKmh;
  final double distanceKm;
  final Duration elapsed;
  final double maxSpeedKmh;
  final double elevationM;

  const _HudPanel({
    required this.config,
    required this.configs,
    required this.activeIndex,
    required this.onPageChanged,
    required this.speedKmh,
    required this.distanceKm,
    required this.elapsed,
    required this.maxSpeedKmh,
    required this.elevationM,
  });

  @override
  State<_HudPanel> createState() => _HudPanelState();
}

class _HudPanelState extends State<_HudPanel> {
  late PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(initialPage: widget.activeIndex);
  }

  @override
  void didUpdateWidget(_HudPanel old) {
    super.didUpdateWidget(old);
    if (old.activeIndex != widget.activeIndex &&
        _ctrl.hasClients &&
        (_ctrl.page?.round() ?? widget.activeIndex) != widget.activeIndex) {
      _ctrl.jumpToPage(widget.activeIndex);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _val(HudMetric m) => _fmtMetric(
        m,
        speedKmh: widget.speedKmh,
        distanceKm: widget.distanceKm,
        elapsed: widget.elapsed,
        maxSpeedKmh: widget.maxSpeedKmh,
        elevationM: widget.elevationM,
      );

  @override
  Widget build(BuildContext context) {
    if (widget.configs.length <= 1) return _buildLayout(widget.config);

    final cfg = widget.configs[widget.activeIndex];
    return Column(
      children: [
        SizedBox(
          height: _panelHeight(cfg),
          child: PageView.builder(
            controller: _ctrl,
            itemCount: widget.configs.length,
            onPageChanged: widget.onPageChanged,
            itemBuilder: (_, i) => _buildLayout(widget.configs[i]),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NavArrow(
              icon: Icons.chevron_left,
              onTap: widget.activeIndex > 0
                  ? () => _ctrl.animateToPage(
                        widget.activeIndex - 1,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
            const SizedBox(width: 8),
            ...List.generate(widget.configs.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == widget.activeIndex ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == widget.activeIndex
                      ? AppColors.accent
                      : AppColors.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
            const SizedBox(width: 8),
            _NavArrow(
              icon: Icons.chevron_right,
              onTap: widget.activeIndex < widget.configs.length - 1
                  ? () => _ctrl.animateToPage(
                        widget.activeIndex + 1,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          cfg.name.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  double _panelHeight(HudConfig cfg) {
    if (cfg.primary.isEmpty) return 90;
    if (cfg.secondary.isEmpty) return 110;
    return 185;
  }

  Widget _buildLayout(HudConfig cfg) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cfg.primary.isNotEmpty)
          Row(
            children: cfg.primary
                .map(
                  (m) => Expanded(
                    child: RoundedCard(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.label,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              letterSpacing: 1.4,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _val(m),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: AppColors.accent,
                              height: 1,
                            ),
                          ),
                          if (m.unit.isNotEmpty)
                            Text(
                              m.unit.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                )
                .expand((w) => [w, const SizedBox(width: 10)])
                .toList()
              ..removeLast(),
          ),
        if (cfg.secondary.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: cfg.secondary
                .map(
                  (m) => Expanded(
                    child: RoundedCard(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.label,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              letterSpacing: 1.3,
                              fontSize: 9,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _val(m),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .expand((w) => [w, const SizedBox(width: 8)])
                .toList()
              ..removeLast(),
          ),
        ],
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavArrow({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        size: 20,
        color: onTap != null
            ? AppColors.textSecondary
            : AppColors.textSecondary.withValues(alpha: 0.2),
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
