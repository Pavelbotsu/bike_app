import 'dart:async';
import 'dart:math' hide log;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/bike_route.dart';
import '../models/gps_point.dart';
import '../models/hud_config.dart';
import '../models/ride.dart';
import '../services/active_ride_store.dart';
import '../services/records_service.dart';
import '../services/ride_tracking_service.dart';
import '../services/ride_history_service.dart';
import '../services/route_service.dart';
import '../utils/geo_utils.dart';
import '../utils/map_tiles.dart';
import '../utils/path_interpolation.dart';
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
  /// When set, the screen skips the idle/countdown flow and resumes an
  /// in-progress ride recovered from disk (e.g. after the app was killed).
  final ActiveRideSnapshot? resumeSnapshot;

  const RideRecordingScreen({super.key, this.resumeSnapshot});

  @override
  State<RideRecordingScreen> createState() => _RideRecordingScreenState();
}

class _RideRecordingScreenState extends State<RideRecordingScreen> {
  final RideTrackingService _trackingService = RideTrackingService();
  final MapController _mapController = MapController();
  final Stopwatch _stopwatch = Stopwatch();
  final PageController _pageController = PageController();
  Timer? _timer;
  StreamSubscription<GpsPoint>? _positionSub;

  // Live metrics
  double _speedKmh = 0;
  double _distanceKm = 0;
  double _maxSpeedKmh = 0;
  double _elevationGainM = 0;
  double _movingSeconds = 0;
  double? _accuracyM;
  Duration _elapsed = Duration.zero;
  GpsPoint? _lastPosition;

  bool _paused = false;
  bool _autoPaused = false;
  bool _fullMap = false;
  double _slowMs = 0.0;
  String? _error;
  DateTime? _startTime;
  final List<LatLng> _routePoints = [];

  // Route-following (Phase 6)
  BikeRoute? _selectedRoute;
  double? _offRouteMeters;
  bool? _onRoute;

  // Wall-clock offset applied when resuming a ride recovered from disk, so
  // the elapsed timer continues from where it left off rather than 0.
  Duration _elapsedOffset = Duration.zero;
  DateTime? _lastPersistedAt;

  // Rolling buffer for display-only speed smoothing (5 samples ≈ 2.5 s)
  final List<double> _recentSpeeds = [];

  // Chart data — appended on each GPS position
  final List<FlSpot> _speedSpots = [];
  final List<FlSpot> _altSpots = [];

  MapStyle _mapStyle = MapStyle.standard;

  // Countdown before ride starts (3,2,1,0=GO!, null=inactive)
  int? _countdown;
  Timer? _countdownTimer;

  // Lap tracking
  final List<LapSplit> _laps = [];
  Duration _lapStartElapsed = Duration.zero;
  double _lapStartKm = 0;

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
    loadMapStyle().then((s) { if (mounted) setState(() => _mapStyle = s); });
    final resumeSnapshot = widget.resumeSnapshot;
    if (resumeSnapshot != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _resumeRide(resumeSnapshot));
    }
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
    // Begin 3-2-1 countdown; GPS is already warming in the background
    setState(() => _countdown = 3);
    HapticFeedback.heavyImpact();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = (_countdown ?? 1) - 1;
      setState(() => _countdown = next);
      HapticFeedback.heavyImpact();
      if (next <= 0) {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            setState(() => _countdown = null);
            _beginRide();
          }
        });
      }
    });
  }

  void _beginRide() {
    WakelockPlus.enable();
    setState(() => _startTime = DateTime.now());
    _stopwatch.start();
    _startElapsedTimer();
    _listen();
    _jumpToFavScreen();
  }

  /// Restores a ride recovered from disk (app was closed/killed mid-ride)
  /// and continues recording from where it left off.
  Future<void> _resumeRide(ActiveRideSnapshot snapshot) async {
    setState(() => _error = null);
    try {
      await _trackingService.start(seed: snapshot.points);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      return;
    }
    final routeId = snapshot.routeId;
    BikeRoute? restoredRoute;
    if (routeId != null) {
      try {
        restoredRoute = await RouteService.instance.loadRouteWithPoints(routeId);
      } catch (_) {
        // Route may have been deleted since the crash — resume without it.
      }
    }
    final recovered = Ride(
      id: '',
      startTime: snapshot.startTime,
      endTime: DateTime.now(),
      points: snapshot.points,
      laps: snapshot.laps,
    );
    WakelockPlus.enable();
    setState(() {
      _selectedRoute = restoredRoute;
      _startTime = snapshot.startTime;
      _distanceKm = recovered.distanceKm;
      _maxSpeedKmh = recovered.maxSpeedKmh;
      _elevationGainM = recovered.elevationGainM;
      _movingSeconds = recovered.movingDuration.inSeconds.toDouble();
      _laps
        ..clear()
        ..addAll(snapshot.laps);
      if (snapshot.points.isNotEmpty) {
        _lastPosition = snapshot.points.last;
        _accuracyM = _lastPosition!.accuracy;
      }
      for (final p in snapshot.points) {
        _routePoints.add(LatLng(p.latitude, p.longitude));
        final t = p.timestamp.difference(snapshot.startTime).inSeconds.toDouble();
        _speedSpots.add(FlSpot(t, double.parse(p.speedKmh.toStringAsFixed(1))));
        _altSpots.add(FlSpot(t, double.parse(p.altitude.toStringAsFixed(1))));
      }
      _elapsedOffset = DateTime.now().difference(snapshot.startTime);
      _elapsed = _elapsedOffset;
      _lapStartElapsed = _elapsedOffset;
      _lapStartKm = _distanceKm;
    });
    _stopwatch.start();
    _startElapsedTimer();
    _listen();
    _jumpToFavScreen();
  }

  void _startElapsedTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = _elapsedOffset + _stopwatch.elapsed);
      if (_elapsed.inSeconds % 5 == 0) {
        _trackingService.updateNotification(
          '${fmtDuration(_elapsed)} · ${fmtDistance(_distanceKm)} km',
        );
      }
    });
  }

  void _jumpToFavScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_favScreen != 0 && _pageController.hasClients) {
        _pageController.jumpToPage(_favScreen);
        setState(() => _screenIndex = _favScreen);
      }
    });
  }

  void _listen() {
    _positionSub = _trackingService.gpsPointStream.listen(
      _onPosition,
      onError: (Object e) {
        if (mounted) setState(() => _error = e.toString());
      },
    );
  }

  void _onPosition(GpsPoint pos) {
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

      // Off-route detection (hysteresis avoids flicker from GPS jitter near
      // the 30 m nominal threshold: leaves "on route" only past 35 m, comes
      // back only once within 25 m).
      final route = _selectedRoute;
      if (route != null && route.waypoints.length >= 2) {
        final dist = distanceToPolylineMeters(newPoint, route.waypoints);
        _offRouteMeters = dist;
        _onRoute = updateOnRouteState(current: _onRoute, distanceMeters: dist);
      }

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

    _persistActiveRide();
  }

  /// Saves a snapshot of the in-progress ride so it can be recovered if the
  /// app is closed before STOP is tapped. Throttled to avoid excessive disk
  /// writes on every GPS sample.
  void _persistActiveRide({bool force = false}) {
    if (_startTime == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastPersistedAt != null &&
        now.difference(_lastPersistedAt!) < const Duration(seconds: 5)) {
      return;
    }
    _lastPersistedAt = now;
    ActiveRideStore.save(
      startTime: _startTime!,
      points: _trackingService.points,
      laps: _laps,
      routeId: _selectedRoute?.id,
    );
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

  void _recordLap() {
    setState(() {
      _laps.add(LapSplit(
        elapsed: _elapsed - _lapStartElapsed,
        distanceKm: _distanceKm - _lapStartKm,
      ));
      _lapStartElapsed = _elapsed;
      _lapStartKm = _distanceKm;
    });
    _persistActiveRide(force: true);
  }

  Future<void> _stopRide() async {
    _timer?.cancel();
    _timer = null;
    _positionSub?.cancel();
    _positionSub = null;
    _stopwatch.stop();

    final baseRide = _trackingService.finish(_startTime!);
    await ActiveRideStore.clear();
    final ride = baseRide.copyWith(laps: _laps, routeId: _selectedRoute?.id);
    WakelockPlus.disable();

    bool save = true;
    if (ride.distanceKm < 0.1) {
      save = await _confirmSaveShortRide(ride.distanceKm * 1000) ?? false;
    }
    if (save) {
      await RideHistoryService.instance.saveRide(ride);
    }
    final newRecords =
        save ? await RecordsService.checkAndUpdate(ride) : <String>[];
    if (!mounted) return;
    if (save) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) =>
                PostRideScreen(ride: ride, newRecords: newRecords)),
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
    _countdownTimer?.cancel();
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
      canPop: _isIdle && _countdown == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmStopFromBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _countdown != null
            ? _buildCountdownOverlay()
            : (_isIdle ? _buildIdleScreen() : _buildRidingStack()),
      ),
    );
  }

  // ─── 3-2-1 countdown overlay ──────────────────────────────────────────────

  Widget _buildCountdownOverlay() {
    final count = _countdown!;
    final isGo = count <= 0;
    return SizedBox.expand(
      child: ColoredBox(
        color: AppColors.background,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isGo ? 'GO!' : '$count',
                  style: TextStyle(
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    color: isGo ? AppColors.accent : AppColors.textPrimary,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isGo ? 'Ride on!' : 'Get ready…',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
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
                const SizedBox(height: 16),
                _buildRouteSelector(),
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

  Widget _buildRouteSelector() {
    final route = _selectedRoute;
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _pickRoute,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.route,
                  color: route != null
                      ? AppColors.highlight
                      : AppColors.textSecondary,
                  size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  route != null ? route.name : 'Follow a route (optional)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: route != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (route != null)
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedRoute = null;
                    _onRoute = null;
                    _offRouteMeters = null;
                  }),
                  child: const Icon(Icons.close,
                      color: AppColors.textSecondary, size: 18),
                )
              else
                const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickRoute() async {
    final routes = await RouteService.instance.loadRoutes();
    if (!mounted) return;
    if (routes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved routes yet — draw one from Profile > My Routes.'),
        ),
      );
      return;
    }
    final picked = await showModalBottomSheet<BikeRoute>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'FOLLOW A ROUTE',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: routes.length,
                itemBuilder: (context, i) {
                  final r = routes[i];
                  return ListTile(
                    leading: const Icon(Icons.route, color: AppColors.highlight),
                    title: Text(r.name,
                        style: const TextStyle(color: AppColors.textPrimary)),
                    subtitle: Text(
                      '${r.waypoints.length} waypoints  ·  ${fmtDistance(r.distanceKm)} km',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    onTap: () => Navigator.of(context).pop(r),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final withPoints = await RouteService.instance.loadRouteWithPoints(picked.id);
    if (mounted) {
      setState(() {
        _selectedRoute = withPoints;
        _onRoute = null;
        _offRouteMeters = null;
      });
    }
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
  // Pure metrics display — no map. When the active HUD config has a grid
  // layout (placements), metrics are rendered at their saved grid positions.
  // Otherwise the classic primary/secondary column layout is used.

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
          urlTemplate: mapTileUrl(_mapStyle),
          userAgentPackageName: 'com.pavelbotsu.velocity',
        ),
        if (_selectedRoute != null && _selectedRoute!.waypoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _selectedRoute!.waypoints.length >= 4
                    ? catmullRomInterpolate(_selectedRoute!.waypoints, steps: 3)
                    : _selectedRoute!.waypoints,
                color: AppColors.textSecondary.withValues(alpha: 0.55),
                strokeWidth: 3,
              ),
            ],
          ),
        if (_routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints.length >= 4
                    ? catmullRomInterpolate(_routePoints, steps: 3)
                    : _routePoints,
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
                  if (_selectedRoute != null && _onRoute != null) ...[
                    const SizedBox(width: 8),
                    _Chip(
                      label: _onRoute!
                          ? 'ON ROUTE'
                          : 'OFF ROUTE · ${_offRouteMeters!.round()} m',
                      color: _onRoute!
                          ? AppColors.success.withValues(alpha: 0.28)
                          : const Color(0xFFE65100).withValues(alpha: 0.38),
                    ),
                  ],
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
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 8,
            shadowColor: const Color(0xFF1A237E).withValues(alpha: 0.45),
          ),
          onPressed: _recordLap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag_rounded, size: 22),
              const SizedBox(height: 2),
              Text(
                'LAP ${_laps.length + 1}',
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ],
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
