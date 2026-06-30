import 'package:shared_preferences/shared_preferences.dart';
import '../models/ride.dart';

class RecordsService {
  static const _kDist = 'prefs_record_dist';
  static const _kSpeed = 'prefs_record_speed';
  static const _kElev = 'prefs_record_elev';
  static const _kDurS = 'prefs_record_dur_s';

  static Future<List<String>> checkAndUpdate(Ride ride) async {
    final prefs = await SharedPreferences.getInstance();
    final broken = <String>[];

    final bestDist = prefs.getDouble(_kDist) ?? 0;
    if (ride.distanceKm > bestDist && ride.distanceKm > 0) {
      await prefs.setDouble(_kDist, ride.distanceKm);
      if (bestDist > 0) broken.add('Longest ride');
    }

    final bestSpeed = prefs.getDouble(_kSpeed) ?? 0;
    if (ride.maxSpeedKmh > bestSpeed && ride.maxSpeedKmh > 0) {
      await prefs.setDouble(_kSpeed, ride.maxSpeedKmh);
      if (bestSpeed > 0) broken.add('Top speed');
    }

    final bestElev = prefs.getDouble(_kElev) ?? 0;
    if (ride.elevationGainM > bestElev && ride.elevationGainM > 0) {
      await prefs.setDouble(_kElev, ride.elevationGainM);
      if (bestElev > 0) broken.add('Most elevation');
    }

    final bestDur = prefs.getInt(_kDurS) ?? 0;
    if (ride.movingDuration.inSeconds > bestDur &&
        ride.movingDuration.inSeconds > 0) {
      await prefs.setInt(_kDurS, ride.movingDuration.inSeconds);
      if (bestDur > 0) broken.add('Longest time');
    }

    return broken;
  }
}
