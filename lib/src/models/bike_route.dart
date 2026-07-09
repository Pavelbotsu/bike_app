import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// A pre-planned path the rider draws on the map — distinct from a recorded
/// [Ride]. Named `BikeRoute` to avoid colliding with Flutter's own `Route`.
class BikeRoute {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<LatLng> waypoints;

  const BikeRoute({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.waypoints,
  });

  double get distanceKm {
    if (waypoints.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < waypoints.length; i++) {
      total += Geolocator.distanceBetween(
        waypoints[i - 1].latitude,
        waypoints[i - 1].longitude,
        waypoints[i].latitude,
        waypoints[i].longitude,
      );
    }
    return total / 1000;
  }
}
