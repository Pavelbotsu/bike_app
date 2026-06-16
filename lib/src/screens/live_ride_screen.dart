import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/hud_config.dart';
import '../services/ride_tracking_service.dart';
import '../services/ride_history_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/rounded_card.dart';
import 'post_ride_screen.dart';

const _kPrefFavScreen = 'ride_default_screen';
const _kMaxChartPoints = 300;

/// Full-screen ride recorder. Pushed as its own route (above the navigation
/// scaffold) so the bottom nav is hidden and the ride can't be abandoned by
/// switching tabs.
///
/// During a ride, three screens are available via horizontal swipe:
///   0 — Data HUD (metrics only, no map)
///   1 — Map + HUD overlay
///   2 — Live speed & altitude charts
///
/// The user can pin any screen as the default (saved to SharedPreferences).
class RideRecordingScreen extends StatefulWidget {
  const RideRecordingScreen({super.key});

  @override
  State<RideRecordingScreen> createState() => _RideRecordingScreenState();
}

class _RideRecordingScreenState extends State<RideRecordingScreen> {
  final RideTrackingService _trackingService = RideTrackingService();
  final MapController _mapController = MapController();
  final Stopwatch _stopwatch = Stopwatch();
  final PageController _pageController = PageController();
  Timer? _timer;
  StreamSubscription<Position>? _positionSub;

  // Live metrics
  double _speedKmh = 0;
  double _distanceKm = 0;
  double _maxSpeedKmh = 0;
  double _elevationGainM = 0;
  double _movingSeconds = 0;
  double? _accuracyM;
  Duration _elapsed = Duration.zero;
  Position? _lastPosition;

  bool _paused = false;
  bool _fullMap = false;
  String? _error;
  DateTime? _startTime;
  final List<LatLng> _routePoints = [];

  // Chart data — appended on each GPS position
  final List<FlSpot> _speedSpots = [];
  final List<FlSpot> _altSpots = [];

  // Screen navigation
  int _screenIndex = 0;
  int _favScreen = 0;

  // Active HUD layout (kept in sync with Settings)
  HudConfig _hud = HudConfig.defaultConfig;

  bool get _isIdle => _startTime == null;
  double get _avgMovingKmh =>
      _movingSeconds > 0 ? _distanceKm / (_movingSeconds / 3600) : 0;

  @override
  void initState() {
    super.initState();
    _loadHud();
    HudConfigService.instance.addListener(_loadHud);
    _loadFavScreen();
  }

  Future<void> _loadHud() async {
    final hud = await HudConfigService.instance.getActive();
    if (mounted) setState(() => _hud = hud);
  }

  Future<void> _loadFavScreen() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _favScreen = prefs.getInt(_kPrefFavScreen) ?? 0);
  }

  Future<void> _saveFavScreen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefFavScreen, _screenIndex);
    if (mounted) setState(() => _favScreen = _screenIndex);
  }

  // ─── Ride lifecycle ────────────────────────────────────────────────────────

  Future<void> _startRide() async {
    setState(() => _error = null);
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
    _listen();

    // Jump to the user's favorite screen once the PageView is laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_favScreen != 0 && _pageController.hasClients) {
        _pageController.jumpToPage(_favScreen);
        setState(() => _screenIndex = _favScreen);
      }
    });
  }

  void _listen() {
    _positionSub = _trackingService.positionStream.listen(
      _onPosition,
      onError: (Object e) {
        if (mounted) setState(() => _error = e.toString());
      },
    );
  }

  void _onPosition(Position pos) {
    if (!mounted) return;
    final newPoint = LatLng(pos.latitude, pos.longitude);
    final t = _stopwatch.elapsed.inSeconds.toDouble();
    setState(() {
      if (_lastPosition != null) {
        _distanceKm += Geolocator.distanceBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              pos.latitude,
              pos.longitude,
            ) /
            1000;
        final dt =
            pos.timestamp.difference(_lastPosition!.timestamp).inMilliseconds /
                1000;
        if (dt > 0 && dt < 30 && pos.speedKmh >= 1.0) {
          _movingSeconds += dt;
        }
        final dAlt = pos.altitude - _lastPosition!.altitude;
        if (dAlt > 0) _elevationGainM += dAlt;
      }
      final dtMs = _lastPosition != null
          ? pos.timestamp
              .difference(_lastPosition!.timestamp)
              .inMilliseconds
              .clamp(0, 5000)
              .toDouble()
          : 0.0;
      _lastPosition = pos;
      _accuracyM = pos.accuracy;
      // Smooth displayed speed with a 5-sample rolling average; max/charts use raw
      _recentSpeeds.add(pos.speedKmh);
      if (_recentSpeeds.length > 5) _recentSpeeds.removeAt(0);
      _speedKmh = _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length;
      if (pos.speedKmh > _maxSpeedKmh) _maxSpeedKmh = pos.speedKmh;
      _routePoints.add(newPoint);

      // Auto-pause / auto-resume
      if (!_paused) {
        if (pos.speedKmh < 1.5) {
          _slowMs += dtMs;
          if (_slowMs >= 8000 && !_autoPaused) {
            _autoPaused = true;
            _stopwatch.stop();
            _trackingService.pause();
          }
        } else if (pos.speedKmh >= 2.5) {
          _slowMs = 0;
          if (_autoPaused) {
            _autoPaused = false;
            _stopwatch.start();
            _trackingService.resume();
          }
        }
      }

      // Feed live charts
      _speedSpots.add(FlSpot(t, double.parse(_speedKmh.toStringAsFixed(1))));
      _altSpots.add(FlSpot(t, double.parse(pos.altitude.toStringAsFixed(1))));
    });

    if (!_fullMap) {
      try {
        _mapController.move(newPoint, 15);
      } catch (_) {}
    }
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      if (_autoPaused) {
        // Manual resume clears auto-pause state
        _autoPaused = false;
        _slowMs = 0;
      }
    });
    if (_paused) {
      _stopwatch.stop();
      _positionSub?.cancel();
      _positionSub = null;
      _trackingService.pause();
    } else {
      _stopwatch.start();
      _trackingService.resume();
      _listen();
    }
  }

  Future<void> _stopRide() async {
    _timer?.cancel();
    _timer = null;
    _positionSub?.cancel();
    _positionSub = null;
    _stopwatch.stop();

    final ride = _trackingService.finish(_startTime!);
    WakelockPlus.disable();

    bool save = true;
    if (ride.distanceKm < 0.1) {
      save = await _confirmSaveShortRide(ride.distanceKm * 1000) ?? false;
    }
    if (save) {
      await RideHistoryService.instance.saveRide(ride);
    }
    if (!mounted) return;
    if (save) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PostRideScreen(ride: ride)),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<bool?> _confirmSaveShortRide(double meters) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Save this ride?'),
        content: Text(
          'This ride is only ${meters.round()} m long. '
          'Do you want to keep it in your history?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('DISCARD',
                style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('SAVE',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmStopFromBack() async {
    final stop = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Stop ride?'),
        content: const Text(
          'Your current ride will be ended.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CONTINUE',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('STOP',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (stop == true) await _stopRide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSub?.cancel();
    _trackingService.stop();
    HudConfigService.instance.removeListener(_loadHud);
    _pageController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // ─── HUD metric mapping ─────────────────────────────────────────────────────

  String _metricValue(HudMetric m) {
    switch (m) {
      case HudMetric.speed:
        return fmtSpeed(_speedKmh);
      case HudMetric.distance:
        return fmtDistance(_distanceKm);
      case HudMetric.time:
        return fmtDuration(_elapsed);
      case HudMetric.avgSpeed:
        return fmtSpeed(_avgMovingKmh);
      case HudMetric.maxSpeed:
        return fmtSpeed(_maxSpeedKmh);
      case HudMetric.elevation:
        return fmtElevation(_elevationGainM);
    }
  }

  // ─── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isIdle,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmStopFromBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _isIdle ? _buildIdleScreen() : _buildRidingStack(),
      ),
    );
  }

  // ─── Idle / ready ─────────────────────────────────────────────────────────

  Widget _buildIdleScreen() {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF090A0E), Color(0xFF0B1119)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.close_rounded,
                            color: AppColors.textSecondary, size: 22),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.directions_bike_rounded,
                    color: AppColors.accent, size: 56),
                const SizedBox(height: 18),
                const Text(
                  'READY TO RIDE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'GPS starts when you tap below',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 20),
                  _ErrorBox(message: _error!),
                ],
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
                  icon: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 26),
                  label: const Text(
                    'START RIDE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Riding: swipeable PageView ────────────────────────────────────────────

  Widget _buildRidingStack() {
    // When full-map mode is active on the map page, hide the indicator and
    // action buttons so the user gets an unobstructed map view.
    final hideOverlay = _fullMap && _screenIndex == 1;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView(
          controller: _pageController,
          onPageChanged: (i) {
            setState(() {
              _screenIndex = i;
              // Auto-exit full-map when swiping away from the map page
              if (i != 1 && _fullMap) _fullMap = false;
            });
          },
          children: [
            _buildDataPage(),
            _buildMapPage(),
            _buildGraphsPage(),
          ],
        ),
        if (!hideOverlay)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(child: _buildPageIndicator()),
                    const SizedBox(height: 8),
                    _buildBottomActionsRow(),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Screen 0: Data HUD ────────────────────────────────────────────────────
  // Pure metrics display — no map. Intended for riders who want maximum
  // readability without the visual complexity of a map underneath.

  Widget _buildDataPage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF090A0E), Color(0xFF0B1119)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: _hud.hasGridLayout
            ? _buildGridDataBody()
            : _buildListDataBody(),
      ),
    );
  }

  // Grid-based rendering — positions derived from HudWidgetPlacement (col, row).
  Widget _buildGridDataBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const hPad = 20.0;
        const statusH = 52.0; // LIVE chip + GPS pill row
        const bottomH = 160.0; // indicator + PAUSE/STOP overlay
        final cellW =
            (constraints.maxWidth - hPad * 2) / kHudGridCols;
        final availH = constraints.maxHeight - statusH - bottomH;
        final cellH = availH / kHudGridRows;

        return Stack(
          children: [
            // Status row
            Positioned(
              top: 14,
              left: hPad,
              right: hPad,
              child: Row(
                children: [
                  _Chip(
                    label: _autoPaused ? 'AUTO-PAUSED' : _paused ? 'PAUSED' : 'LIVE',
                    color: (_paused || _autoPaused)
                        ? const Color(0xFFE65100).withValues(alpha: 0.38)
                        : AppColors.accent.withValues(alpha: 0.28),
                  ),
                  const Spacer(),
                  _GpsPill(
                      accuracyM: _accuracyM,
                      acquiring: _lastPosition == null),
                ],
              ),
            ),
            // Metric tiles at grid positions
            for (final p in _hud.placements)
              Positioned(
                left: hPad + p.col * cellW,
                top: statusH + p.row * cellH,
                width: cellW,
                height: cellH,
                child: _buildGridMetricTile(p.metric, cellW, cellH),
              ),
          ],
        );
      },
    );
  }

  Widget _buildGridMetricTile(HudMetric m, double cellW, double cellH) {
    final valueFontSize = (cellH * 0.42).clamp(24.0, 64.0);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            m.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _metricValue(m),
              style: TextStyle(
                fontSize: valueFontSize,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                height: 0.95,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (m.unit.isNotEmpty)
            Text(
              m.unit.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
        ],
      ),
    );
  }

  // Classic column-based rendering (no grid placements configured).
  Widget _buildListDataBody() {
    return Padding(
      // Bottom padding accounts for the floating indicator + action buttons
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Chip(
                label: _paused ? 'PAUSED' : 'LIVE',
                color: _paused
                    ? const Color(0xFFE65100).withValues(alpha: 0.38)
                    : AppColors.accent.withValues(alpha: 0.28),
              ),
              const Spacer(),
              _GpsPill(
                accuracyM: _accuracyM,
                acquiring: _lastPosition == null,
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildPrimary(),
          if (_hud.secondary.isNotEmpty) ...[
            const SizedBox(height: 32),
            _buildSecondary(),
          ],
        ],
      ),
    );
  }

  // ─── Screen 1: Map ─────────────────────────────────────────────────────────

  Widget _buildMapPage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildFullScreenMap(),
        // HUD gradient overlay — hidden in full-map mode
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!_fullMap) _buildGaugesOverlay(),
              if (_fullMap)
                SizedBox(height: MediaQuery.of(context).padding.top + 12),
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 8),
                child: _buildFullScreenToggle(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Screen 2: Live Charts ─────────────────────────────────────────────────

  Widget _buildGraphsPage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF090A0E), Color(0xFF0B1119)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Chip(
                    label: _autoPaused ? 'AUTO-PAUSED' : _paused ? 'PAUSED' : 'LIVE',
                    color: (_paused || _autoPaused)
                        ? const Color(0xFFE65100).withValues(alpha: 0.38)
                        : AppColors.accent.withValues(alpha: 0.28),
                  ),
                  const Spacer(),
                  _GpsPill(
                    accuracyM: _accuracyM,
                    acquiring: _lastPosition == null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: RoundedCard(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                  child: _buildLiveChart(
                    spots: _downsampled(_speedSpots),
                    color: AppColors.accent,
                    label: 'SPEED',
                    unit: 'km/h',
                    currentValue: _speedKmh,
                    fmt: fmtSpeed,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: RoundedCard(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                  child: _buildLiveChart(
                    spots: _downsampled(_altSpots),
                    color: AppColors.highlight,
                    label: 'ALTITUDE',
                    unit: 'm',
                    currentValue: _lastPosition?.altitude ?? 0,
                    fmt: fmtElevation,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveChart({
    required List<FlSpot> spots,
    required Color color,
    required String label,
    required String unit,
    required double currentValue,
    required String Function(double) fmt,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const Spacer(),
            Text(
              '${fmt(currentValue)} $unit',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: spots.length < 2
              ? Center(
                  child: Text(
                    spots.isEmpty ? 'Waiting for GPS…' : 'Collecting data…',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                )
              : _chartWidget(spots, color),
        ),
      ],
    );
  }

  Widget _chartWidget(List<FlSpot> spots, Color color) {
    final ys = spots.map((s) => s.y).toList();
    final minY = ys.reduce(min);
    final maxY = ys.reduce(max);
    final range = maxY - minY;
    final pad = max(range * 0.15, 1.0);

    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.30),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _downsampled(List<FlSpot> spots) {
    if (spots.length <= _kMaxChartPoints) return spots;
    final ratio = spots.length / _kMaxChartPoints;
    return List.generate(
      _kMaxChartPoints,
      (i) => spots[(i * ratio).floor()],
    );
  }

  // ─── Page indicator ────────────────────────────────────────────────────────

  Widget _buildPageIndicator() {
    const pageIcons = [
      Icons.speed_rounded,       // Data HUD
      Icons.map_rounded,         // Map
      Icons.show_chart_rounded,  // Graphs
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(3, (i) {
            final active = _screenIndex == i;
            final isFavNotActive = _favScreen == i && !active;
            return GestureDetector(
              onTap: () => _pageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.accent.withValues(alpha: 0.22)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  pageIcons[i],
                  size: 18,
                  color: active
                      ? AppColors.accent
                      : isFavNotActive
                          ? AppColors.accent.withValues(alpha: 0.55)
                          : AppColors.textSecondary.withValues(alpha: 0.55),
                ),
              ),
            );
          }),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: Colors.white.withValues(alpha: 0.12),
          ),
          GestureDetector(
            onTap: _saveFavScreen,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Icon(
                _favScreen == _screenIndex
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 18,
                color: _favScreen == _screenIndex
                    ? AppColors.accent
                    : AppColors.textSecondary.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Full-screen map ───────────────────────────────────────────────────────

  Widget _buildFullScreenMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _routePoints.isEmpty
            ? const LatLng(52.0, 19.0)
            : _routePoints.last,
        initialZoom: 15,
        interactionOptions: InteractionOptions(
          flags: _fullMap ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.bike_app',
        ),
        if (_routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                color: AppColors.accent,
                strokeWidth: 4,
              ),
            ],
          ),
        if (_routePoints.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: _routePoints.last,
                child: const _PositionMarker(),
              ),
            ],
          ),
      ],
    );
  }

  // ─── Gauges overlay (HUD-driven) — shown on map page ──────────────────────

  Widget _buildGaugesOverlay() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.88),
            Colors.black.withValues(alpha: 0.62),
            Colors.black.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.60, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Chip(
                    label: _autoPaused ? 'AUTO-PAUSED' : _paused ? 'PAUSED' : 'LIVE',
                    color: (_paused || _autoPaused)
                        ? const Color(0xFFE65100).withValues(alpha: 0.38)
                        : AppColors.accent.withValues(alpha: 0.28),
                  ),
                  const Spacer(),
                  _GpsPill(
                    accuracyM: _accuracyM,
                    acquiring: _lastPosition == null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildPrimary(),
              if (_hud.secondary.isNotEmpty) ...[
                const SizedBox(height: 18),
                _buildSecondary(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimary() {
    final metrics =
        _hud.primary.isEmpty ? const [HudMetric.speed] : _hud.primary;
    if (metrics.length == 1) {
      return _bigMetric(metrics.first, accent: true, size: 72);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _bigMetric(metrics[0], accent: true, size: 46)),
        Container(
          width: 1,
          height: 54,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: Colors.white.withValues(alpha: 0.12),
        ),
        Expanded(child: _bigMetric(metrics[1], accent: false, size: 46)),
      ],
    );
  }

  Widget _bigMetric(HudMetric m,
      {required bool accent, required double size}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          m.label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _metricValue(m),
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            color: accent ? AppColors.accent : Colors.white,
            height: 0.9,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (m.unit.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            m.unit.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSecondary() {
    return Row(
      children:
          _hud.secondary.map((m) => Expanded(child: _smallMetric(m))).toList(),
    );
  }

  Widget _smallMetric(HudMetric m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          m.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                _metricValue(m),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.0,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (m.unit.isNotEmpty) ...[
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  m.unit,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ─── Fullscreen toggle (map page only) ────────────────────────────────────

  Widget _buildFullScreenToggle() {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final exitingFullMap = _fullMap;
          setState(() => _fullMap = !_fullMap);
          if (exitingFullMap && _routePoints.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                _mapController.move(_routePoints.last, 15);
              } catch (_) {}
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            _fullMap
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            color: Colors.white.withValues(alpha: 0.90),
            size: 22,
          ),
        ),
      ),
    );
  }

  // ─── Bottom action buttons (PAUSE / STOP) ─────────────────────────────────

  Widget _buildBottomActionsRow() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 8,
              shadowColor: const Color(0xFFE65100).withValues(alpha: 0.45),
            ),
            onPressed: _togglePause,
            icon: Icon(
              _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 26,
            ),
            label: Text(
              _paused ? 'RESUME' : 'PAUSE',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 8,
              shadowColor: const Color(0xFFB71C1C).withValues(alpha: 0.45),
            ),
            onPressed: _stopRide,
            icon: const Icon(Icons.stop_circle_rounded, size: 26),
            label: const Text(
              'STOP',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Supporting widgets ─────────────────────────────────────────────────────

class _GpsPill extends StatelessWidget {
  final double? accuracyM;
  final bool acquiring;

  const _GpsPill({required this.accuracyM, required this.acquiring});

  @override
  Widget build(BuildContext context) {
    final Color dot;
    final String text;
    if (acquiring || accuracyM == null) {
      dot = AppColors.textSecondary;
      text = 'ACQUIRING…';
    } else {
      final acc = accuracyM!;
      dot = acc <= 8
          ? AppColors.success
          : acc <= 20
              ? const Color(0xFFE6A100)
              : Colors.redAccent;
      text = '±${acc.round()} m';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            'GPS $text',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFB71C1C).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFB71C1C).withValues(alpha: 0.50)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
      ),
    );
  }
}

class _PositionMarker extends StatelessWidget {
  const _PositionMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.55),
            blurRadius: 10,
            spreadRadius: 3,
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
