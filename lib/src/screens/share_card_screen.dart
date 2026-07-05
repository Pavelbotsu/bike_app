import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gps_point.dart';
import '../models/ride.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/map_tiles.dart';
import '../utils/path_interpolation.dart';

// ─── Share stat enum ────────────────────────────────────────────────────────

enum ShareStat {
  distance,
  avgSpeed,
  maxSpeed,
  duration,
  elevation,
  movingTime,
}

extension ShareStatLabel on ShareStat {
  String get label {
    switch (this) {
      case ShareStat.distance:  return 'DISTANCE';
      case ShareStat.avgSpeed:  return 'AVG SPEED';
      case ShareStat.maxSpeed:  return 'MAX SPEED';
      case ShareStat.duration:  return 'DURATION';
      case ShareStat.elevation: return 'ELEVATION';
      case ShareStat.movingTime: return 'MOVING TIME';
    }
  }

  String value(Ride ride) {
    switch (this) {
      case ShareStat.distance:   return '${fmtDistance(ride.distanceKm)} km';
      case ShareStat.avgSpeed:   return '${fmtSpeed(ride.avgMovingSpeedKmh)} km/h';
      case ShareStat.maxSpeed:   return '${fmtSpeed(ride.maxSpeedKmh)} km/h';
      case ShareStat.duration:   return fmtDuration(ride.duration);
      case ShareStat.elevation:  return '${fmtElevation(ride.elevationGainM)} m';
      case ShareStat.movingTime: return fmtDuration(ride.movingDuration);
    }
  }
}

const _kPrefStatKey = 'share_card_stats';
const _kPrefBackgroundKey = 'share_card_background';
const _kMaxStats = 4;

// ─── Card background ────────────────────────────────────────────────────────

/// What's drawn behind the route line and stats on the exported card.
enum ShareCardBackground { solid, map, transparent }

extension ShareCardBackgroundLabel on ShareCardBackground {
  String get label {
    switch (this) {
      case ShareCardBackground.solid:       return 'BLACK';
      case ShareCardBackground.map:         return 'MAP';
      case ShareCardBackground.transparent: return 'TRANSPARENT';
    }
  }

  IconData get icon {
    switch (this) {
      case ShareCardBackground.solid:       return Icons.square_rounded;
      case ShareCardBackground.map:         return Icons.map_rounded;
      case ShareCardBackground.transparent: return Icons.check_box_outline_blank_rounded;
    }
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class ShareCardScreen extends StatefulWidget {
  final Ride ride;

  const ShareCardScreen({super.key, required this.ride});

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final GlobalKey _cardKey = GlobalKey();

  String? _locationName;
  List<ShareStat> _selectedStats = const [
    ShareStat.distance,
    ShareStat.avgSpeed,
    ShareStat.duration,
    ShareStat.elevation,
  ];
  bool _sharing = false;
  bool _loadingLocation = true;
  ShareCardBackground _background = ShareCardBackground.solid;

  Ride get ride => widget.ride;

  @override
  void initState() {
    super.initState();
    _loadStatPrefs();
    _loadBackgroundPref();
    _fetchLocation();
  }

  Future<void> _loadBackgroundPref() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPrefBackgroundKey);
    if (saved == null || !mounted) return;
    try {
      setState(() => _background = ShareCardBackground.values.byName(saved));
    } catch (_) {}
  }

  Future<void> _setBackground(ShareCardBackground bg) async {
    setState(() => _background = bg);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefBackgroundKey, bg.name);
  }

  Future<void> _loadStatPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kPrefStatKey);
    if (saved != null && saved.isNotEmpty) {
      final parsed = saved
          .map((s) {
            try {
              return ShareStat.values.byName(s);
            } catch (_) {
              return null;
            }
          })
          .whereType<ShareStat>()
          .toList();
      if (parsed.isNotEmpty && mounted) {
        setState(() => _selectedStats = parsed);
      }
    }
  }

  Future<void> _saveStatPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kPrefStatKey,
      _selectedStats.map((s) => s.name).toList(),
    );
  }

  Future<void> _fetchLocation() async {
    if (ride.points.isEmpty) {
      if (mounted) setState(() => _loadingLocation = false);
      return;
    }
    final pt = ride.points.first;
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=${pt.latitude}&lon=${pt.longitude}&zoom=10',
      );
      final response = await http
          .get(uri, headers: {'User-Agent': 'Velocity-App/1.0'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null && mounted) {
          final name = address['city'] as String? ??
              address['town'] as String? ??
              address['village'] as String? ??
              address['county'] as String?;
          setState(() => _locationName = name);
        }
      }
    } catch (_) {
      // No network or timeout — location stays null (card renders without it)
    }
    if (mounted) setState(() => _loadingLocation = false);
  }

  void _toggleStat(ShareStat stat) {
    setState(() {
      if (_selectedStats.contains(stat)) {
        if (_selectedStats.length > 1) {
          _selectedStats = List.from(_selectedStats)..remove(stat);
        }
      } else if (_selectedStats.length < _kMaxStats) {
        _selectedStats = List.from(_selectedStats)..add(stat);
      }
    });
    _saveStatPrefs();
  }

  Future<void> _shareImage() async {
    setState(() => _sharing = true);
    try {
      // Wait one frame so the RepaintBoundary is fully painted
      await Future.delayed(const Duration(milliseconds: 80));

      final boundary = _cardKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/velocity_share_${ride.id}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: _locationName != null
            ? 'My ride in $_locationName — ${fmtDistance(ride.distanceKm)} km'
            : 'My ride — ${fmtDistance(ride.distanceKm)} km',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'SHARE RIDE',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          if (_sharing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _shareImage,
              icon: const Icon(Icons.share_rounded,
                  size: 18, color: AppColors.accent),
              label: const Text(
                'SHARE',
                style: TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card preview
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      if (_background == ShareCardBackground.transparent)
                        const Positioned.fill(
                          child: CustomPaint(painter: _CheckerboardPainter()),
                        ),
                      RepaintBoundary(
                        key: _cardKey,
                        child: _buildCard(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Background customisation
              const Text(
                'CARD BACKGROUND',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Map background needs a route · transparent exports as PNG with alpha',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    ShareCardBackground.values.map(_buildBackgroundChip).toList(),
              ),
              const SizedBox(height: 24),
              // Stat customisation
              const Text(
                'STATS ON CARD',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Up to $_kMaxStats · tap to add or remove',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ShareStat.values.map(_buildStatChip).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(ShareStat stat) {
    final active = _selectedStats.contains(stat);
    final canAdd = _selectedStats.length < _kMaxStats;
    final disabled = !active && !canAdd;

    return GestureDetector(
      onTap: disabled ? null : () => _toggleStat(stat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.18)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppColors.accent
                : disabled
                    ? const Color(0xFF1E2030)
                    : const Color(0xFF2A2D3E),
          ),
        ),
        child: Text(
          stat.label,
          style: TextStyle(
            color: active
                ? AppColors.accent
                : disabled
                    ? AppColors.textSecondary.withValues(alpha: 0.45)
                    : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundChip(ShareCardBackground bg) {
    final active = _background == bg;
    final disabled = bg == ShareCardBackground.map && ride.points.length < 2;

    return GestureDetector(
      onTap: disabled ? null : () => _setBackground(bg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.18)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppColors.accent
                : disabled
                    ? const Color(0xFF1E2030)
                    : const Color(0xFF2A2D3E),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              bg.icon,
              size: 14,
              color: active
                  ? AppColors.accent
                  : disabled
                      ? AppColors.textSecondary.withValues(alpha: 0.45)
                      : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              bg.label,
              style: TextStyle(
                color: active
                    ? AppColors.accent
                    : disabled
                        ? AppColors.textSecondary.withValues(alpha: 0.45)
                        : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Share card widget ───────────────────────────────────────────────────────

  Widget _buildCard() {
    const cardWidth = 320.0;
    const cardPad = 20.0;

    final pts = _downsample(ride.points);

    // Date string
    final dt = ride.startTime;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateStr =
        '${months[dt.month - 1]} ${dt.day}, ${dt.year}';

    final transparent = _background == ShareCardBackground.transparent;

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: transparent ? Colors.transparent : AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: transparent
            ? null
            : Border.all(
                color: Colors.white.withValues(alpha: 0.06), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
                cardPad, cardPad, cardPad, 0),
            child: Row(
              children: [
                const Icon(Icons.directions_bike_rounded,
                    color: AppColors.accent, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'VELOCITY',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Location + ride name ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: cardPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_locationName != null) ...[
                  Text(
                    _locationName!.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                ] else if (_loadingLocation) ...[
                  Container(
                    width: 120,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  ride.displayName,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Route map ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: cardPad),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: cardWidth - cardPad * 2, // square canvas
                width: double.infinity,
                color: _background == ShareCardBackground.map
                    ? null
                    : (transparent ? Colors.transparent : const Color(0xFF0D0E14)),
                child: _buildRoutePanel(pts),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Stats row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
                cardPad, 0, cardPad, cardPad),
            child: Row(
              children: _selectedStats
                  .map((stat) => Expanded(
                        child: _buildStatTile(stat),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Route thumbnail content: flat-colour custom-painted line (solid /
  /// transparent backgrounds) or a real tiled map (map background).
  Widget _buildRoutePanel(List<GpsPoint> pts) {
    if (pts.length < 2) {
      return const Center(
        child: Icon(Icons.route_rounded,
            color: AppColors.textSecondary, size: 32),
      );
    }
    if (_background == ShareCardBackground.map) {
      return _buildRouteMap(pts);
    }
    return CustomPaint(painter: _RoutePainter(points: pts));
  }

  Widget _buildRouteMap(List<GpsPoint> pts) {
    final latLngs = pts.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final smoothed = catmullRomInterpolate(latLngs, steps: 4);
    return IgnorePointer(
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(latLngs),
            padding: const EdgeInsets.all(16),
          ),
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          TileLayer(
            urlTemplate: mapTileUrl(MapStyle.standard),
            userAgentPackageName: 'com.pavelbotsu.velocity',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: smoothed,
                color: AppColors.accent,
                strokeWidth: 3.5,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: latLngs.first,
                child: _routeDot(const Color(0xFF3BD5AC)),
              ),
              Marker(
                point: latLngs.last,
                child: _routeDot(Colors.redAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _routeDot(Color color) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );

  Widget _buildStatTile(ShareStat stat) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            stat.value(ride),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 8,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  List<GpsPoint> _downsample(List<GpsPoint> pts, {int max = 300}) {
    if (pts.length <= max) return pts;
    final ratio = pts.length / max;
    return List.generate(max, (i) => pts[(i * ratio).floor()]);
  }
}

// ─── Checkerboard backdrop ────────────────────────────────────────────────────
// Preview-only affordance so a "transparent" card reads as transparent
// against the app's dark screen background. Painted behind the
// RepaintBoundary, so it never ends up in the exported PNG.

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  static const _cell = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0xFF2A2D3E);
    final dark = Paint()..color = const Color(0xFF15161F);
    for (double y = 0; y < size.height; y += _cell) {
      for (double x = 0; x < size.width; x += _cell) {
        final isDark = ((x / _cell).floor() + (y / _cell).floor()).isEven;
        canvas.drawRect(
          Rect.fromLTWH(x, y, _cell, _cell),
          isDark ? dark : light,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerboardPainter old) => false;
}

// ─── Route painter ───────────────────────────────────────────────────────────

class _RoutePainter extends CustomPainter {
  final List<GpsPoint> points;

  const _RoutePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // Compute bounding box
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // Mercator correction for proportional display
    final meanLat = (minLat + maxLat) / 2;
    final cosLat = cos(meanLat * pi / 180);
    final lngRange = (maxLng - minLng) * cosLat;
    final latRange = maxLat - minLat;

    const padding = 20.0;
    final availW = size.width - padding * 2;
    final availH = size.height - padding * 2;

    final scale = (lngRange > 0 && latRange > 0)
        ? min(availW / lngRange, availH / latRange)
        : 1.0;

    final routeW = lngRange * scale;
    final routeH = latRange * scale;
    final originX = padding + (availW - routeW) / 2;
    final originY = padding + (availH - routeH) / 2;

    Offset toOffset(GpsPoint p) => Offset(
          originX + (p.longitude - minLng) * cosLat * scale,
          originY + (maxLat - p.latitude) * scale,
        );

    // Speed range for colour mapping
    final speeds =
        points.map((p) => p.speedKmh.clamp(0.0, double.infinity)).toList();
    final minSpd = speeds.reduce(min);
    final maxSpd = speeds.reduce(max);
    final spdRange = max(maxSpd - minSpd, 1.0);

    // Draw each segment
    for (int i = 1; i < points.length; i++) {
      final avgSpd = (points[i - 1].speedKmh + points[i].speedKmh) / 2;
      final t = ((avgSpd - minSpd) / spdRange).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = _speedColor(t)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(toOffset(points[i - 1]), toOffset(points[i]), paint);
    }

    // Start dot (green)
    canvas.drawCircle(
      toOffset(points.first),
      4.5,
      Paint()..color = const Color(0xFF3BD5AC),
    );
    // End dot (red)
    canvas.drawCircle(
      toOffset(points.last),
      4.5,
      Paint()..color = Colors.redAccent,
    );
  }

  /// t=0 (slow) → blue (240°) … t=1 (fast) → red (0°).
  Color _speedColor(double t) {
    final hue = (1.0 - t) * 240.0;
    return HSVColor.fromAHSV(1.0, hue, 1.0, 0.95).toColor();
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.points != points;
}
