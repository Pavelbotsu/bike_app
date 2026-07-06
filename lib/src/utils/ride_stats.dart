import 'package:geolocator/geolocator.dart';
import '../models/ride.dart';

/// One bucket of a distance-weighted grade histogram.
class GradeBucket {
  final String label;
  final double distanceKm;
  const GradeBucket(this.label, this.distanceKm);
}

const List<String> kGradeBucketLabels = [
  'STEEP DOWN',
  'DOWN',
  'FLAT',
  'UP',
  'STEEP UP',
];

/// Buckets the ride's per-segment grade (via [Ride.gradePctAt]) weighted by
/// segment distance, so bucket totals sum to the ride's total distance
/// (unlike a point-count histogram, which would over-weight slow sections).
List<GradeBucket> gradeHistogram(Ride ride) {
  final totalsKm = List<double>.filled(kGradeBucketLabels.length, 0);
  final points = ride.points;
  for (int i = 1; i < points.length; i++) {
    final segMeters = Geolocator.distanceBetween(
      points[i - 1].latitude,
      points[i - 1].longitude,
      points[i].latitude,
      points[i].longitude,
    );
    totalsKm[_bucketIndex(ride.gradePctAt(i))] += segMeters / 1000;
  }
  return [
    for (int i = 0; i < kGradeBucketLabels.length; i++)
      GradeBucket(kGradeBucketLabels[i], totalsKm[i]),
  ];
}

int _bucketIndex(double gradePct) {
  if (gradePct < -8) return 0;
  if (gradePct < -2) return 1;
  if (gradePct <= 2) return 2;
  if (gradePct <= 8) return 3;
  return 4;
}

/// A transparent, explainable effort score — no hidden proprietary formula.
/// 100 means "a typical ride for you"; higher means harder than usual.
class EffortResult {
  final int score;

  /// Distance adjusted for climbing (100 m of climb counted as ~1 flat km).
  final double elevAdjKm;

  /// This ride's average moving speed relative to the rider's historical
  /// average, clamped to [0.6, 1.6] so a single outlier can't blow up the
  /// score.
  final double intensity;

  const EffortResult({
    required this.score,
    required this.elevAdjKm,
    required this.intensity,
  });
}

EffortResult effortScore(Ride ride, List<Ride> priorRides) {
  final elevAdjKm = ride.distanceKm + ride.elevationGainM / 100;

  final baselineRides =
      priorRides.where((r) => r.distanceKm > 0.5).toList(growable: false);

  var intensity = 1.0;
  if (baselineRides.isNotEmpty && ride.avgMovingSpeedKmh > 0) {
    final histAvgSpeed = baselineRides
            .map((r) => r.avgMovingSpeedKmh)
            .fold<double>(0, (sum, v) => sum + v) /
        baselineRides.length;
    if (histAvgSpeed > 0) {
      intensity = (ride.avgMovingSpeedKmh / histAvgSpeed).clamp(0.6, 1.6);
    }
  }

  final rawEffort = elevAdjKm * intensity;

  // Baseline "typical difficulty" is the median elevation-adjusted distance
  // of the rider's own prior rides — not their full raw effort, which would
  // require each prior ride's own intensity and create circular dependence.
  var baseline = 15.0;
  if (baselineRides.length >= 3) {
    final elevAdjKms = baselineRides
        .map((r) => r.distanceKm + r.elevationGainM / 100)
        .toList()
      ..sort();
    baseline = _median(elevAdjKms);
  }

  final score = baseline > 0 ? (100 * rawEffort / baseline).round() : 100;
  return EffortResult(
    score: score.clamp(0, 999),
    elevAdjKm: elevAdjKm,
    intensity: intensity,
  );
}

double _median(List<double> sorted) {
  final n = sorted.length;
  final mid = n ~/ 2;
  return n.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}
