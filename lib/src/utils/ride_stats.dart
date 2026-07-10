import 'package:geolocator/geolocator.dart';
import '../models/ride.dart';

/// The ride with the shortest total duration in [rides], or null if empty.
/// Used to find a rider's personal-best time on a given route.
Ride? fastestRide(List<Ride> rides) {
  if (rides.isEmpty) return null;
  return rides.reduce((a, b) => a.duration < b.duration ? a : b);
}

/// The best (highest) average moving speed among [rides], or null if empty.
double? bestAvgMovingSpeedKmh(List<Ride> rides) {
  if (rides.isEmpty) return null;
  return rides.map((r) => r.avgMovingSpeedKmh).reduce((a, b) => a > b ? a : b);
}

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

/// Monday 00:00 (local) of the week containing [date] — the same week
/// definition already used by HistoryScreen's "this week" summary.
DateTime _mondayOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

/// Total ride distance for one Monday-start week.
class WeekVolume {
  final DateTime weekStart;
  final double distanceKm;
  const WeekVolume(this.weekStart, this.distanceKm);
}

/// Buckets ride distance into Monday-start weeks, oldest to newest, for the
/// last [weeks] weeks including the current (possibly partial) week.
List<WeekVolume> weeklyDistanceKm(List<Ride> rides, {int weeks = 10}) {
  final thisMonday = _mondayOf(DateTime.now());
  final mondays = [
    for (int i = weeks - 1; i >= 0; i--)
      thisMonday.subtract(Duration(days: 7 * i)),
  ];
  final totals = {for (final m in mondays) m: 0.0};
  for (final ride in rides) {
    final monday = _mondayOf(ride.startTime);
    final total = totals[monday];
    if (total != null) totals[monday] = total + ride.distanceKm;
  }
  return [for (final m in mondays) WeekVolume(m, totals[m]!)];
}

Set<DateTime> _weeksWithRides(List<Ride> rides) =>
    rides.map((r) => _mondayOf(r.startTime)).toSet();

/// Consecutive Monday-start weeks with >=1 ride, counting back from the
/// current week. If the current week has no ride yet but last week does,
/// counting starts from last week so the streak doesn't read as broken
/// mid-week.
int currentWeeklyStreak(List<Ride> rides) {
  if (rides.isEmpty) return 0;
  final weeks = _weeksWithRides(rides);
  var cursor = _mondayOf(DateTime.now());
  if (!weeks.contains(cursor)) {
    final lastWeek = cursor.subtract(const Duration(days: 7));
    if (!weeks.contains(lastWeek)) return 0;
    cursor = lastWeek;
  }
  var streak = 0;
  while (weeks.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 7));
  }
  return streak;
}

/// Longest run of consecutive Monday-start weeks with >=1 ride, anywhere in
/// the rider's history. Reused by the achievements screen.
int longestWeeklyStreak(List<Ride> rides) {
  if (rides.isEmpty) return 0;
  final weeks = _weeksWithRides(rides).toList()..sort();
  var longest = 1;
  var current = 1;
  for (int i = 1; i < weeks.length; i++) {
    if (weeks[i].difference(weeks[i - 1]).inDays == 7) {
      current++;
    } else {
      current = 1;
    }
    if (current > longest) longest = current;
  }
  return longest;
}
