import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gps_point.dart';
import '../models/ride.dart';

/// A recovered in-progress ride, restored from disk after the app process
/// was killed mid-ride.
class ActiveRideSnapshot {
  final DateTime startTime;
  final List<GpsPoint> points;
  final List<LapSplit> laps;

  const ActiveRideSnapshot({
    required this.startTime,
    required this.points,
    required this.laps,
  });
}

/// Persists the currently-recording ride to disk so it can be recovered if
/// the app is closed (swiped away, killed by the OS) before the rider taps
/// STOP. [RideRecordingScreen] saves a snapshot on every few GPS points and
/// clears it once the ride is stopped normally.
class ActiveRideStore {
  static const _key = 'active_ride_v1';

  static Future<void> save({
    required DateTime startTime,
    required List<GpsPoint> points,
    required List<LapSplit> laps,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'startTime': startTime.millisecondsSinceEpoch,
        'points': points.map((p) => p.toJson()).toList(),
        'laps': laps.map((l) => l.toJson()).toList(),
      }),
    );
  }

  static Future<ActiveRideSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final points = (json['points'] as List<dynamic>)
          .map((p) => GpsPoint.fromJson(p as Map<String, dynamic>))
          .toList();
      if (points.isEmpty) return null;
      final laps = (json['laps'] as List<dynamic>? ?? const [])
          .map((l) => LapSplit.fromJson(l as Map<String, dynamic>))
          .toList();
      return ActiveRideSnapshot(
        startTime:
            DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
        points: points,
        laps: laps,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
