import 'dart:async';
import 'package:geolocator/geolocator.dart';

enum LocationMode {
  economy,
  performance,
  highSpeed,
}

class LocationService {
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();
  StreamSubscription<Position>? _subscription;
  LocationMode _currentMode = LocationMode.economy;

  Stream<Position> get positionStream => _positionController.stream;

  LocationMode get currentMode => _currentMode;

  Future<void> start() async {
    // Check and request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied, we cannot request permissions.');
    }

    _startStream();
  }

  void setMode(LocationMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      _restartStream();
    }
  }

  void _startStream() {
    final LocationSettings settings = _getSettings();
    _subscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (Position position) {
        _positionController.add(position);
        // Automatically switch to high speed mode if speed > 20 km/h
        if (position.speed != null && position.speed! > (20 / 3.6)) {
          if (_currentMode != LocationMode.highSpeed) {
            setMode(LocationMode.highSpeed);
          }
        }
      },
      onError: (error) {
        _positionController.addError(error);
      },
    );
  }

  LocationSettings _getSettings() {
    Duration interval;
    switch (_currentMode) {
      case LocationMode.economy:
        interval = const Duration(seconds: 5);
        break;
      case LocationMode.performance:
        interval = const Duration(seconds: 1);
        break;
      case LocationMode.highSpeed:
        interval = const Duration(milliseconds: 500);
        break;
    }

    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      timeLimit: interval,
    );
  }

  void _restartStream() {
    _subscription?.cancel();
    _startStream();
  }

  void stop() {
    _subscription?.cancel();
    _positionController.close();
  }
}