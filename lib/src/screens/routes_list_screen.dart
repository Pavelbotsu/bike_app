import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/bike_route.dart';
import '../services/route_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/map_tiles.dart';
import '../utils/path_interpolation.dart';
import '../widgets/rounded_card.dart';
import 'route_editor_screen.dart';

/// Route list/management panel: create, rename, delete, and preview saved
/// routes. Mirrors HistoryScreen's swipe-to-delete / long-press-rename
/// pattern for a saved ride.
class RoutesListScreen extends StatefulWidget {
  const RoutesListScreen({super.key});

  @override
  State<RoutesListScreen> createState() => _RoutesListScreenState();
}

class _RoutesListScreenState extends State<RoutesListScreen> {
  List<BikeRoute> _routes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final routes = await RouteService.instance.loadRoutes();
    if (mounted) {
      setState(() {
        _routes = routes;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: AppColors.textPrimary),
                  ),
                  const Text(
                    'MY ROUTES',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: _createRoute,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _createRoute() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RouteEditorScreen()),
    );
    if (saved == true) _loadRoutes();
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_routes.isEmpty) {
      return _emptyState();
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 90),
      itemCount: _routes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _buildDismissibleTile(_routes[i]),
    );
  }

  Widget _buildDismissibleTile(BikeRoute route) {
    return Dismissible(
      key: ValueKey(route.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(route),
      onDismissed: (_) async {
        setState(() => _routes.removeWhere((r) => r.id == route.id));
        await RouteService.instance.deleteRoute(route.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFB71C1C).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: _RouteTile(
        route: route,
        onTap: () => _openRoute(route),
        onRename: () => _renameRoute(route),
      ),
    );
  }

  void _openRoute(BikeRoute route) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _RouteDetailScreen(route: route)),
    );
  }

  Future<bool> _confirmDelete(BikeRoute route) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete route?'),
        content: Text(
          'Permanently delete "${route.name}"? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _renameRoute(BikeRoute route) async {
    final controller = TextEditingController(text: route.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rename route'),
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
            child: const Text('SAVE', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await RouteService.instance.renameRoute(route.id, newName);
      _loadRoutes();
    }
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.map_outlined, size: 48, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            'No routes yet',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tap + to draw your first route',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  final BikeRoute route;
  final VoidCallback onTap;
  final VoidCallback onRename;

  const _RouteTile({
    required this.route,
    required this.onTap,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onRename,
      child: RoundedCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.highlight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.route,
                  color: AppColors.highlight, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${route.waypoints.length} waypoints  ·  ${fmtDistance(route.distanceKm)} km',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
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
}

/// Read-only route preview — map pan/zoom is allowed, but tapping never
/// adds a waypoint (unlike RouteEditorScreen).
class _RouteDetailScreen extends StatelessWidget {
  final BikeRoute route;

  const _RouteDetailScreen({required this.route});

  @override
  Widget build(BuildContext context) {
    final points = route.waypoints;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: AppColors.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      route.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<MapStyle>(
                future: loadMapStyle(),
                builder: (context, snapshot) {
                  final style = snapshot.data ?? MapStyle.standard;
                  return FlutterMap(
                    options: MapOptions(
                      initialCenter: points.isEmpty
                          ? const LatLng(52.0, 19.0)
                          : points[points.length ~/ 2],
                      initialZoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: mapTileUrl(style),
                        userAgentPackageName: 'com.pavelbotsu.velocity',
                      ),
                      if (points.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: points.length >= 4
                                  ? catmullRomInterpolate(points, steps: 4)
                                  : points,
                              color: AppColors.highlight,
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                      if (points.isNotEmpty)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: points.first,
                              width: 20,
                              height: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                            if (points.length > 1)
                              Marker(
                                point: points.last,
                                width: 20,
                                height: 20,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: RoundedCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: _DetailStat(
                        label: 'DISTANCE',
                        value: '${fmtDistance(route.distanceKm)} km',
                      ),
                    ),
                    Expanded(
                      child: _DetailStat(
                        label: 'WAYPOINTS',
                        value: route.waypoints.length.toString(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;

  const _DetailStat({required this.label, required this.value});

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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
