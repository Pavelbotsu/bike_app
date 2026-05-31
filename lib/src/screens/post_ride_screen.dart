import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../models/gps_point.dart';
import '../models/ride.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/rounded_card.dart';

class PostRideScreen extends StatefulWidget {
  final Ride ride;

  const PostRideScreen({super.key, required this.ride});

  @override
  State<PostRideScreen> createState() => _PostRideScreenState();
}

class _PostRideScreenState extends State<PostRideScreen> {
  bool _exporting = false;

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
                    _buildTimesCard(),
                    if (ride.points.length >= 5) ...[
                      const SizedBox(height: 16),
                      _buildChartCard(
                        title: 'SPEED',
                        unit: 'km/h',
                        color: AppColors.accent,
                        spots: _speedSpots(),
                      ),
                      const SizedBox(height: 16),
                      _buildChartCard(
                        title: 'ELEVATION',
                        unit: 'm',
                        color: AppColors.highlight,
                        spots: _elevationSpots(),
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
          const Expanded(
            child: Text(
              'RIDE SUMMARY',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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

  Widget _buildMap() {
    final latLngPoints =
        ride.points.map((p) => LatLng(p.latitude, p.longitude)).toList();

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

    return SizedBox(
      height: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: FlutterMap(
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
            PolylineLayer(
              polylines: [
                Polyline(
                  points: latLngPoints,
                  color: AppColors.accent,
                  strokeWidth: 4,
                ),
              ],
            ),
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
      ),
    );
  }

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
                  value: '${ride.distanceKm.toStringAsFixed(2)} km',
                ),
              ),
              Expanded(
                child: _StatCol(
                  label: 'DURATION',
                  value: _fmtDuration(ride.duration),
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
                  value: '${ride.avgSpeedKmh.toStringAsFixed(1)} km/h',
                  color: AppColors.accent,
                ),
              ),
              Expanded(
                child: _StatCol(
                  label: 'MAX SPEED',
                  value: '${ride.maxSpeedKmh.toStringAsFixed(1)} km/h',
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          if (ride.elevationGainM > 0.5) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _StatCol(
                    label: 'ELEVATION GAIN',
                    value: '${ride.elevationGainM.toStringAsFixed(0)} m',
                    color: AppColors.highlight,
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
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
  }) {
    if (spots.isEmpty) return const SizedBox.shrink();

    final minY =
        spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY =
        spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
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

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _fmtClock(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
