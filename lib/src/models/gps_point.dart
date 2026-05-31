import 'package:geolocator/geolocator.dart';

class GpsPoint {
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double altitude;
  final DateTime timestamp;

  const GpsPoint({
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.altitude,
    required this.timestamp,
  });

  factory GpsPoint.fromPosition(Position pos) => GpsPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
        speedKmh: pos.speed * 3.6,
        altitude: pos.altitude,
        timestamp: pos.timestamp,
      );

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'speed': speedKmh,
        'alt': altitude,
        'ts': timestamp.millisecondsSinceEpoch,
      };

  factory GpsPoint.fromJson(Map<String, dynamic> json) => GpsPoint(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        speedKmh: (json['speed'] as num).toDouble(),
        altitude: (json['alt'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
      );
}
