import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/bike_route.dart';
import '../services/route_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/map_tiles.dart';
import '../utils/path_interpolation.dart';

/// Draw a new route by tapping waypoints on the map, then save it with a
/// name. Creation only — renaming/deleting an existing route is handled
/// from RoutesListScreen.
class RouteEditorScreen extends StatefulWidget {
  const RouteEditorScreen({super.key});

  @override
  State<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

class _RouteEditorScreenState extends State<RouteEditorScreen> {
  final MapController _mapController = MapController();
  final List<LatLng> _waypoints = [];
  MapStyle _mapStyle = MapStyle.standard;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    loadMapStyle().then((s) {
      if (mounted) setState(() => _mapStyle = s);
    });
  }

  double get _distanceKm {
    if (_waypoints.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < _waypoints.length; i++) {
      total += Geolocator.distanceBetween(
        _waypoints[i - 1].latitude,
        _waypoints[i - 1].longitude,
        _waypoints[i].latitude,
        _waypoints[i].longitude,
      );
    }
    return total / 1000;
  }

  void _addWaypoint(LatLng point) => setState(() => _waypoints.add(point));

  void _removeLast() {
    if (_waypoints.isEmpty) return;
    setState(() => _waypoints.removeLast());
  }

  void _clear() {
    if (_waypoints.isEmpty) return;
    setState(() => _waypoints.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMap()),
            _buildToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textPrimary),
          ),
          const Expanded(
            child: Text(
              'DRAW ROUTE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter:
            _waypoints.isEmpty ? const LatLng(52.0, 19.0) : _waypoints.last,
        initialZoom: 14,
        onTap: (tapPosition, point) => _addWaypoint(point),
      ),
      children: [
        TileLayer(
          urlTemplate: mapTileUrl(_mapStyle),
          userAgentPackageName: 'com.pavelbotsu.velocity',
        ),
        if (_waypoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _waypoints.length >= 4
                    ? catmullRomInterpolate(_waypoints, steps: 4)
                    : _waypoints,
                color: AppColors.highlight,
                strokeWidth: 4,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (int i = 0; i < _waypoints.length; i++)
              Marker(
                point: _waypoints[i],
                width: 20,
                height: 20,
                child: _WaypointMarker(
                  isFirst: i == 0,
                  isLast: i == _waypoints.length - 1,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_waypoints.length} waypoints  ·  ${fmtDistance(_distanceKm)} km',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _waypoints.isEmpty ? null : _removeLast,
                    child: const Text('UNDO',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  TextButton(
                    onPressed: _waypoints.isEmpty ? null : _clear,
                    child: const Text('CLEAR',
                        style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _waypoints.length < 2 || _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'SAVE ROUTE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = await _promptName();
    if (name == null || name.trim().isEmpty) return;

    setState(() => _saving = true);
    final route = BikeRoute(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      createdAt: DateTime.now(),
      waypoints: List.of(_waypoints),
    );
    await RouteService.instance.saveRoute(route);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<String?> _promptName() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Name this route'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Route name',
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
  }
}

class _WaypointMarker extends StatelessWidget {
  final bool isFirst;
  final bool isLast;

  const _WaypointMarker({required this.isFirst, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = isFirst
        ? AppColors.success
        : (isLast ? AppColors.accent : AppColors.highlight);
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
