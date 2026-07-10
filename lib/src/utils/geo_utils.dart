import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Minimum distance in meters from [current] to the polyline defined by the
/// ordered waypoints in [route], via point-to-segment projection.
///
/// Each segment is projected onto with a local equirectangular (flat-earth)
/// approximation — accurate enough at ride-following scale (tens to low
/// hundreds of meters) — then the true geodesic distance to that projected
/// point is measured with [Geolocator.distanceBetween], keeping this in step
/// with every other distance calculation in the app.
double distanceToPolylineMeters(LatLng current, List<LatLng> route) {
  if (route.isEmpty) return double.infinity;
  if (route.length == 1) {
    return Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      route.first.latitude,
      route.first.longitude,
    );
  }

  var minDist = double.infinity;
  for (int i = 1; i < route.length; i++) {
    final proj = _projectOntoSegment(current, route[i - 1], route[i]);
    final dist = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      proj.latitude,
      proj.longitude,
    );
    if (dist < minDist) minDist = dist;
  }
  return minDist;
}

/// Updates on/off-route hysteresis state given the latest off-route
/// distance. With no prior state (first fix), compares directly against the
/// midpoint of the two thresholds. Once established, only flips to off past
/// [offThreshold] and only flips back to on once within [onThreshold] — this
/// asymmetric band absorbs GPS jitter that would otherwise flicker the
/// indicator right at the boundary.
bool updateOnRouteState({
  required bool? current,
  required double distanceMeters,
  double onThreshold = 25,
  double offThreshold = 35,
}) {
  if (current == null) {
    return distanceMeters <= (onThreshold + offThreshold) / 2;
  }
  if (current && distanceMeters > offThreshold) return false;
  if (!current && distanceMeters < onThreshold) return true;
  return current;
}

/// Projects [point] onto the segment [a]-[b], clamped to the segment (not
/// the infinite line), using longitude scaled by cos(latitude) so the x/y
/// axes are both in "degrees of latitude" units before the projection math.
LatLng _projectOntoSegment(LatLng point, LatLng a, LatLng b) {
  final xScale = cos(a.latitude * (pi / 180));

  final ax = a.longitude * xScale;
  final ay = a.latitude;
  final bx = b.longitude * xScale;
  final by = b.latitude;
  final px = point.longitude * xScale;
  final py = point.latitude;

  final dx = bx - ax;
  final dy = by - ay;
  final lenSq = dx * dx + dy * dy;

  var t = lenSq > 0 ? ((px - ax) * dx + (py - ay) * dy) / lenSq : 0.0;
  t = t.clamp(0.0, 1.0);

  return LatLng(ay + t * dy, (ax + t * dx) / xScale);
}
