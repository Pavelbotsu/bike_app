import 'ride.dart';
import '../utils/ride_stats.dart';

/// Aggregate lifetime stats an achievement predicate can check against.
class RiderStats {
  final int rideCount;
  final double totalKm;
  final double totalElevationM;
  final double longestRideKm;
  final int longestWeeklyStreakWeeks;

  const RiderStats({
    required this.rideCount,
    required this.totalKm,
    required this.totalElevationM,
    required this.longestRideKm,
    required this.longestWeeklyStreakWeeks,
  });

  factory RiderStats.fromRides(List<Ride> rides) {
    if (rides.isEmpty) {
      return const RiderStats(
        rideCount: 0,
        totalKm: 0,
        totalElevationM: 0,
        longestRideKm: 0,
        longestWeeklyStreakWeeks: 0,
      );
    }
    return RiderStats(
      rideCount: rides.length,
      totalKm: rides.fold(0.0, (sum, r) => sum + r.distanceKm),
      totalElevationM: rides.fold(0.0, (sum, r) => sum + r.elevationGainM),
      longestRideKm:
          rides.fold(0.0, (max, r) => r.distanceKm > max ? r.distanceKm : max),
      longestWeeklyStreakWeeks: longestWeeklyStreak(rides),
    );
  }
}

/// A milestone badge. Evaluated on the fly from [RiderStats] — no persisted
/// "unlocked" state, so there's nothing to migrate or keep in sync with the
/// ride history.
class Achievement {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final bool Function(RiderStats stats) isUnlocked;

  const Achievement({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.isUnlocked,
  });
}

final List<Achievement> kAchievements = [
  Achievement(
    id: 'first_ride',
    title: 'First Ride',
    emoji: '🚲',
    description: 'Complete your first ride.',
    isUnlocked: (s) => s.rideCount >= 1,
  ),
  Achievement(
    id: 'half_century',
    title: 'Half-Century',
    emoji: '🌗',
    description: 'Ride 50 km or more in a single ride.',
    isUnlocked: (s) => s.longestRideKm >= 50,
  ),
  Achievement(
    id: 'century',
    title: 'Century',
    emoji: '💯',
    description: 'Ride 100 km or more in a single ride.',
    isUnlocked: (s) => s.longestRideKm >= 100,
  ),
  Achievement(
    id: 'thousand_km_club',
    title: '1000 km Club',
    emoji: '🏅',
    description: 'Reach 1,000 km of lifetime distance.',
    isUnlocked: (s) => s.totalKm >= 1000,
  ),
  Achievement(
    id: 'everest',
    title: 'Everest',
    emoji: '🏔️',
    description: 'Climb 8,848 m of lifetime elevation — the height of Everest.',
    isUnlocked: (s) => s.totalElevationM >= 8848,
  ),
  Achievement(
    id: 'consistent',
    title: 'Consistent',
    emoji: '🔥',
    description: 'Ride at least once a week for 4 weeks in a row.',
    isUnlocked: (s) => s.longestWeeklyStreakWeeks >= 4,
  ),
  Achievement(
    id: 'explorer',
    title: 'Explorer',
    emoji: '🧭',
    description: 'Complete 25 rides.',
    isUnlocked: (s) => s.rideCount >= 25,
  ),
];
