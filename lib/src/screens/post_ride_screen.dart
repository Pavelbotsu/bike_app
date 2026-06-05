import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../models/gps_point.dart';
import '../models/ride.dart';
import '../services/export_service.dart';
import '../services/ride_history_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/rounded_card.dart';

class PostRideScreen extends StatefulWidget {
  final Ride ride;

  const PostRideScreen({super.key, required this.ride});

  @override
  State<PostRideScreen> createState() => _PostRideScreenState();
}

class _PostRideScreenState extends State<PostRideScreen> {
  bool _exporting = false;
  bool _gradientRoute = true;
  late String _name = widget.ride.displayName;

  Ride get ride => widget.ride;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMap(),
                    const SizedBox(height: 16),
                    _buildStatsCard(),
                    const SizedBox(height: 16),
                    if (_hasElevationData) ...[
                      _buildAnalysisCard(),
                      const SizedBox(height: 16),
                    ],
                    _buildTimesCard(),
                    if (ride.points.length >= 5) ...[
                      const SizedBox(height: 16),
                      _buildChartCard(
                        title: 'SPEED',
                        unit: 'km/h',
                        color: AppColors.accent,
                        spots: _speedSpots(),
                        fmt: fmtSpeed,
                      ),
                      const SizedBox(height: 16),
                      _buildChartCard(
                        title: 'ELEVATION',
                        unit: 'm',
                        color: AppColors.highlight,
                        spots: _elevationSpots(),
                        fmt: fmtElevation,
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildDoneButton(context),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasElevationData =>
      ride.elevationGainM > 0.5 || ride.elevationLossM > 0.5;

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new,
                color: AppColors.textPrimary),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _renameRide,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined,
                      size: 15, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          _exporting
              ? const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  onPressed: _showExportSheet,
                  icon: const Icon(Icons.upload_outlined,
                      color: AppColors.textPrimary),
                  tooltip: 'Export',
                ),
        ],
      ),
    );
  }

  Future<void> _renameRide() async {
    final controller = TextEditingController(text: _name);
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
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('SAVE',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != _name) {
      setState(() => _name = newName);
      await RideHistoryService.instance.renameRide(ride.id, newName);
    }
  }

  Future<void> _showExportSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111420),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'EXPORT RIDE',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _ExportTile(
                icon: Icons.route,
                label: 'Export as GPX',
                subtitle: 'Compatible with Komoot, Strava, OsmAnd',
                onTap: () {
                  Navigator.pop(context);
                  _export('gpx');
                },
              ),
              const SizedBox(height: 12),
              _ExportTile(
                icon: Icons.monitor_heart_outlined,
                label: 'Export as TCX',
                subtitle: 'Compatible with Garmin Connect, TrainingPeaks',
                onTap: () {
                  Navigator.pop(context);
                  _export('tcx');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    try {
      final file = format == 'gpx'
          ? await ExportService.exportGpx(ride)
          : await ExportService.exportTcx(ride);
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ─── Map (with optional gradient colouring) ─────────────────────────────────

  Widget _buildMap() {
    final pts = _downsample(ride.points);
    final latLngPoints =
        pts.map((p) => LatLng(p.latitude, p.longitude)).toList();

    if (latLngPoints.length < 2) {
      return RoundedCard(
        padding: EdgeInsets.zero,
        child: const SizedBox(
          height: 180,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined,
                    size: 36, color: AppColors.textSecondary),
                SizedBox(height: 8),
                Text(
                  'Not enough GPS data',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    double minLat = latLngPoints.first.latitude;
    double maxLat = latLngPoints.first.latitude;
    double minLng = latLngPoints.first.longitude;
    double maxLng = latLngPoints.first.longitude;
    for (final p in latLngPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    final polylines = _gradientRoute && _hasElevationData
        ? _gradientSegments(pts)
        : [
            Polyline(
              points: latLngPoints,
              color: AppColors.accent,
              strokeWidth: 4,
            ),
          ];

    return SizedBox(
      height: 240,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(40),
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.bike_app',
                ),
                PolylineLayer(polylines: polylines),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: latLngPoints.first,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Marker(
                      point: latLngPoints.last,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_hasElevationData) ...[
              Positioned(
                top: 10,
                right: 10,
                child: _MapToggle(
                  gradient: _gradientRoute,
                  onTap: () =>
                      setState(() => _gradientRoute = !_gradientRoute),
                ),
              ),
              if (_gradientRoute)
                const Positioned(
                  left: 10,
                  bottom: 10,
                  child: _GradientLegend(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// One short polyline per segment, coloured by gradient so climbs and
  /// descents are visible along the route.
  List<Polyline> _gradientSegments(List<GpsPoint> pts) {
    final segments = <Polyline>[];
    for (int i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      final horiz = Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
      final grade = horiz < 5
          ? 0.0
          : ((b.altitude - a.altitude) / horiz * 100).clamp(-40.0, 40.0);
      segments.add(
        Polyline(
          points: [
            LatLng(a.latitude, a.longitude),
            LatLng(b.latitude, b.longitude),
          ],
          color: gradeColor(grade),
          strokeWidth: 5,
        ),
      );
    }
    return segments;
  }

  // ─── Stat cards ─────────────────────────────────────────────────────────────

  Widget _buildStatsCard() {
    return RoundedCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCol(
                  label: 'DISTANCE',
                  value: '${fmtDistance(ride.distanceKm)} km',
                ),
              ),
              Expanded(
                child: _StatCol(
                  label: 'DURATION',
                  value: fmtDuration(ride.duration),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatCol(
                  label: 'AVG SPEED',
                  value: '${fmtSpeed(ride.avgMovingSpeedKmh)} km/h',
                  color: AppColors.accent,
                ),
              ),
              Expanded(
                child: _StatCol(
                  label: 'MAX SPEED',
                  value: '${fmtSpeed(ride.maxSpeedKmh)} km/h',
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard() {
    return RoundedCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CLIMB ANALYSIS',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatCol(
                  label: 'ELEVATION GAIN',
                  value: '${fmtElevation(ride.elevationGainM)} m',
                  color: AppColors.highlight,
                ),
              ),
              Expanded(
                child: _StatCol(
                  label: 'ELEVATION LOSS',
                  value: '${fmtElevation(ride.elevationLossM)} m',
                  color: const Color(0xFF1E88E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatCol(
                  label: 'MAX GRADE',
                  value: fmtGrade(ride.maxGradePct),
                ),
              ),
              Expanded(
                child: _StatCol(
                  label: 'MOVING TIME',
                  value: fmtDuration(ride.movingDuration),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimesCard() {
    return RoundedCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          _TimeRow(label: 'STARTED', value: _fmtClock(ride.startTime)),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1E2030), height: 1),
          const SizedBox(height: 12),
          _TimeRow(label: 'ENDED', value: _fmtClock(ride.endTime)),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String unit,
    required Color color,
    required List<FlSpot> spots,
    required String Function(double) fmt,
  }) {
    if (spots.isEmpty) return const SizedBox.shrink();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final range = (maxY - minY).abs();
    final pad = range < 1 ? 1.0 : range * 0.1;
    final yMin = (minY - pad).floorToDouble();
    final yMax = (maxY + pad).ceilToDouble();

    return RoundedCard(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '$title ($unit)',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                letterSpacing: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                minY: yMin,
                maxY: yMax,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1E2030),
                    getTooltipItems: (touchedSpots) => touchedSpots
                        .map(
                          (s) => LineTooltipItem(
                            '${fmt(s.y)} $unit',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: color,
                    barWidth: 2.5,
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.12),
                    ),
                    dotData: const FlDotData(show: false),
                  ),
                ],
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0xFF1E2030),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(0),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(1),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text(
          'DONE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  List<FlSpot> _speedSpots() {
    final sampled = _downsample(ride.points);
    return [
      for (int i = 0; i < sampled.length; i++)
        FlSpot(
          sampled[i].timestamp.difference(ride.startTime).inSeconds / 60.0,
          sampled[i].speedKmh.clamp(0, double.infinity),
        ),
    ];
  }

  List<FlSpot> _elevationSpots() {
    final sampled = _downsample(ride.points);
    double dist = 0;
    final spots = <FlSpot>[];
    for (int i = 0; i < sampled.length; i++) {
      if (i > 0) {
        dist += Geolocator.distanceBetween(
              sampled[i - 1].latitude,
              sampled[i - 1].longitude,
              sampled[i].latitude,
              sampled[i].longitude,
            ) /
            1000;
      }
      spots.add(FlSpot(dist, sampled[i].altitude));
    }
    return spots;
  }

  List<GpsPoint> _downsample(List<GpsPoint> points, {int max = 200}) {
    if (points.length <= max) return points;
    final step = points.length / max;
    return List.generate(
      max,
      (i) => points[(i * step).round().clamp(0, points.length - 1)],
    );
  }

  String _fmtClock(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// Colour ramp for route gradient: warm = climb, grey = flat, cool = descent.
Color gradeColor(double grade) {
  if (grade >= 8) return const Color(0xFFD32F2F);
  if (grade >= 4) return const Color(0xFFF4511E);
  if (grade >= 1.5) return const Color(0xFFFFB300);
  if (grade > -1.5) return const Color(0xFF9E9E9E);
  if (grade > -4) return const Color(0xFF26C6DA);
  if (grade > -8) return const Color(0xFF1E88E5);
  return const Color(0xFF1565C0);
}

class _MapToggle extends StatelessWidget {
  final bool gradient;
  final VoidCallback onTap;

  const _MapToggle({required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                gradient ? Icons.terrain : Icons.show_chart,
                color: gradient ? AppColors.accent : Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                gradient ? 'GRADIENT' : 'ROUTE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientLegend extends StatelessWidget {
  const _GradientLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _LegendDot(color: Color(0xFFD32F2F), label: 'Climb'),
          SizedBox(width: 10),
          _LegendDot(color: Color(0xFF9E9E9E), label: 'Flat'),
          SizedBox(width: 10),
          _LegendDot(color: Color(0xFF1E88E5), label: 'Descent'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCol({
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
            fontSize: 11,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ExportTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ExportTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF181C28),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final String value;

  const _TimeRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            letterSpacing: 1.4,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
