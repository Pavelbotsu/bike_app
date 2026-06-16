import 'package:latlong2/latlong.dart';

/// Catmull-Rom spline interpolation for GPS polylines.
/// Applied only at display time — never store the result.
///
/// [steps] controls how many points are inserted between each pair.
/// Use steps=4 for post-ride static maps, steps=3 for live maps.
List<LatLng> catmullRomInterpolate(List<LatLng> points, {int steps = 4}) {
  if (points.length < 2) return points;

  // Phantom endpoints: repeat first/last so the curve passes through them.
  final ctrl = [points.first, ...points, points.last];
  final result = <LatLng>[];

  for (int i = 1; i < ctrl.length - 2; i++) {
    final p0 = ctrl[i - 1];
    final p1 = ctrl[i];
    final p2 = ctrl[i + 1];
    final p3 = ctrl[i + 2];

    if (i == 1) result.add(p1);

    for (int s = 1; s <= steps; s++) {
      final t = s / steps;
      result.add(_crPoint(p0, p1, p2, p3, t));
    }
  }

  return result;
}

LatLng _crPoint(LatLng p0, LatLng p1, LatLng p2, LatLng p3, double t) {
  final t2 = t * t;
  final t3 = t2 * t;

  final lat = 0.5 *
      ((2.0 * p1.latitude) +
          (-p0.latitude + p2.latitude) * t +
          (2.0 * p0.latitude - 5.0 * p1.latitude + 4.0 * p2.latitude - p3.latitude) * t2 +
          (-p0.latitude + 3.0 * p1.latitude - 3.0 * p2.latitude + p3.latitude) * t3);

  final lng = 0.5 *
      ((2.0 * p1.longitude) +
          (-p0.longitude + p2.longitude) * t +
          (2.0 * p0.longitude - 5.0 * p1.longitude + 4.0 * p2.longitude - p3.longitude) * t2 +
          (-p0.longitude + 3.0 * p1.longitude - 3.0 * p2.longitude + p3.longitude) * t3);

  return LatLng(lat, lng);
}
