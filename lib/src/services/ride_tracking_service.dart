import 'dart:async';
import 'location_service.dart';
import '../models/gps_point.dart';
import '../models/ride.dart';

class RideTrackingService {
  final LocationService _locationService = LocationService();
  final List<GpsPoint> _points = [];
  StreamSubscription<GpsPoint>? _sub;
  bool _recording = false;

  Stream<GpsPoint> get gpsPointStream => _locationService.gpsPointStream;

  List<GpsPoint> get points => List.unmodifiable(_points);

  Future<void> start() async {
    _points.clear();
    _recording = true;
    await _locationService.start();
    _sub = _locationService.gpsPointStream.listen((GpsPoint point) {
      if (_recording) _points.add(point);
    });
  }

  void pause() => _recording = false;

  void resume() => _recording = true;

  Ride finish(DateTime startTime) {
    _recording = false;
    _sub?.cancel();
    _sub = null;
    _locationService.stop();
    final ride = Ride(
      id: startTime.millisecondsSinceEpoch.toString(),
      startTime: startTime,
      endTime: DateTime.now(),
      points: List.from(_points),
    );
    _points.clear();
    return ride;
  }

  void stop() {
    _recording = false;
    _sub?.cancel();
    _sub = null;
    _locationService.stop();
    _points.clear();
  }
}
