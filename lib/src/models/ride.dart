import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'gps_point.dart';

class LapSplit {
  final Duration elapsed;
  final double distanceKm;
  const LapSplit({required this.elapsed, required this.distanceKm});

  Map<String, dynamic> toJson() =>
      {'ms': elapsed.inMilliseconds, 'km': distanceKm};

  factory LapSplit.fromJson(Map<String, dynamic> j) => LapSplit(
        elapsed: Duration(milliseconds: j['ms'] as int),
        distanceKm: (j['km'] as num).toDouble(),
      );

  static String encodeList(List<LapSplit> laps) =>
      jsonEncode(laps.map((l) => l.toJson()).toList());

  static List<LapSplit> decodeList(String? json) {
    if (json == null || json.isEmpty) return const [];
    return (jsonDecode(json) as List<dynamic>)
        .map((e) => LapSplit.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class Ride {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final List<GpsPoint> points;

  /// User-given title. When null a sensible default is derived from the
  /// start time (see [displayName]).
  final String? name;

  /// Optional free-text note added after the ride.
  final String? notes;

  final List<LapSplit> laps;

  /// Id of the [BikeRoute] this ride followed, if the rider picked one to
  /// follow before starting. Null for untagged rides.
  final String? routeId;

  const Ride({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.points,
    this.name,
    this.notes,
    this.laps = const [],
    this.routeId,
  });

  Ride copyWith({
    String? name,
    String? notes,
    List<LapSplit>? laps,
    String? routeId,
  }) =>
      Ride(
        id: id,
        startTime: startTime,
        endTime: endTime,
        points: points,
        name: name ?? this.name,
        notes: notes ?? this.notes,
        laps: laps ?? this.laps,
        routeId: routeId ?? this.routeId,
      );

  /// Title shown in lists/summaries. Falls back to a time-of-day label
  /// (Strava-style) when the rider hasn't named the ride.
  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    final h = startTime.hour;
    if (h < 5) return 'Night Ride';
    if (h < 12) return 'Morning Ride';
    if (h < 17) return 'Afternoon Ride';
    if (h < 21) return 'Evening Ride';
    return 'Night Ride';
  }

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

  /// Time actually spent moving (samples above ~1 km/h). Used for a realistic
  /// moving-average speed that isn't dragged down by stops at lights etc.
  Duration get movingDuration {
    if (points.length < 2) return Duration.zero;
    var moving = Duration.zero;
    for (int i = 1; i < points.length; i++) {
      final dt = points[i].timestamp.difference(points[i - 1].timestamp);
      if (dt <= Duration.zero || dt > const Duration(seconds: 30)) continue;
      if (points[i].speedKmh >= 1.0) moving += dt;
    }
    return moving;
  }

  double get avgSpeedKmh {
    if (points.isEmpty) return 0;
    return points.fold<double>(0, (sum, p) => sum + p.speedKmh) / points.length;
  }

  /// Average speed over moving time only (km/h).
  double get avgMovingSpeedKmh {
    final secs = movingDuration.inSeconds;
    if (secs <= 0) return 0;
    return distanceKm / (secs / 3600);
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

  double get elevationLossM {
    if (points.length < 2) return 0;
    double loss = 0;
    for (int i = 1; i < points.length; i++) {
      final delta = points[i].altitude - points[i - 1].altitude;
      if (delta < 0) loss += -delta;
    }
    return loss;
  }

  /// Per-segment grade in percent, clamped to ±40% and ignoring sub-5 m
  /// segments to suppress GPS altitude jitter.
  double gradePctAt(int i) {
    if (i < 1 || i >= points.length) return 0;
    final horiz = Geolocator.distanceBetween(
      points[i - 1].latitude,
      points[i - 1].longitude,
      points[i].latitude,
      points[i].longitude,
    );
    if (horiz < 5) return 0;
    final rise = points[i].altitude - points[i - 1].altitude;
    final grade = rise / horiz * 100;
    return grade.clamp(-40.0, 40.0);
  }

  double get maxGradePct {
    double maxG = 0;
    for (int i = 1; i < points.length; i++) {
      final g = gradePctAt(i);
      if (g > maxG) maxG = g;
    }
    return maxG;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory Ride.fromJson(Map<String, dynamic> json) => Ride(
        id: json['id'] as String,
        name: json['name'] as String?,
        startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
        endTime: DateTime.fromMillisecondsSinceEpoch(json['endTime'] as int),
        points: (json['points'] as List<dynamic>)
            .map((p) => GpsPoint.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}
