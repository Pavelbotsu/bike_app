import 'package:geolocator/geolocator.dart';

class GpsPoint {
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double altitude;
  final double accuracy;
  final DateTime timestamp;

  const GpsPoint({
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.altitude,
    this.accuracy = 0.0,
    required this.timestamp,
  });

  factory GpsPoint.fromPosition(Position pos) => GpsPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
        speedKmh: pos.speed * 3.6,
        altitude: pos.altitude,
        accuracy: pos.accuracy,
        timestamp: pos.timestamp,
      );

  factory GpsPoint.fromNativeMap(Map<Object?, Object?> map) => GpsPoint(
        latitude: (map['lat'] as num).toDouble(),
        longitude: (map['lng'] as num).toDouble(),
        speedKmh: (map['speed'] as num).toDouble() * 3.6,
        altitude: (map['alt'] as num).toDouble(),
        accuracy: (map['accuracy'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['ts'] as int),
      );

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'speed': speedKmh,
        'alt': altitude,
        'acc': accuracy,
        'ts': timestamp.millisecondsSinceEpoch,
      };

  factory GpsPoint.fromJson(Map<String, dynamic> json) => GpsPoint(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        speedKmh: (json['speed'] as num).toDouble(),
        altitude: (json['alt'] as num).toDouble(),
        accuracy: (json['acc'] as num? ?? 0.0).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
      );
}
