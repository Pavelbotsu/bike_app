import 'package:geolocator/geolocator.dart';
import 'gps_point.dart';

class Ride {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final List<GpsPoint> points;

  const Ride({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.points,
  });

  double get distanceKm {
    if (points.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return total / 1000;
  }

  Duration get duration => endTime.difference(startTime);

  double get avgSpeedKmh {
    if (points.isEmpty) return 0;
    return points.fold<double>(0, (sum, p) => sum + p.speedKmh) / points.length;
  }

  double get maxSpeedKmh {
    if (points.isEmpty) return 0;
    return points.fold<double>(0, (max, p) => p.speedKmh > max ? p.speedKmh : max);
  }

  double get elevationGainM {
    if (points.length < 2) return 0;
    double gain = 0;
    for (int i = 1; i < points.length; i++) {
      final delta = points[i].altitude - points[i - 1].altitude;
      if (delta > 0) gain += delta;
    }
    return gain;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory Ride.fromJson(Map<String, dynamic> json) => Ride(
        id: json['id'] as String,
        startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
        endTime: DateTime.fromMillisecondsSinceEpoch(json['endTime'] as int),
        points: (json['points'] as List<dynamic>)
            .map((p) => GpsPoint.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}
