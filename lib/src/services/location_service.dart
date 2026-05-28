import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';

enum LocationMode {
  economy,
  performance,
  highSpeed,
}

const double _highSpeedThresholdMs = 20 / 3.6;
const double _lowSpeedThresholdMs = 15 / 3.6;

class LocationService {
  StreamController<Position> _positionController = StreamController<Position>.broadcast();
  StreamSubscription<Position>? _subscription;
  LocationMode _currentMode = LocationMode.economy;
  bool _isRunning = false;

  Stream<Position> get positionStream => _positionController.stream;

  LocationMode get currentMode => _currentMode;

  Future<void> start() async {
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

    _isRunning = true;
    _startStream();
  }

  void setMode(LocationMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      if (_isRunning) {
        _restartStream();
      }
    }
  }

  void _startStream() {
    final LocationSettings settings = _getSettings();
    _subscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (Position position) {
        if (_positionController.isClosed) return;
        _positionController.add(position);
        _autoAdjustMode(position.speed);
      },
      onError: (error) {
        if (!_positionController.isClosed) {
          _positionController.addError(error);
        }
      },
    );
  }

  void _autoAdjustMode(double speed) {
    if (speed > _highSpeedThresholdMs && _currentMode != LocationMode.highSpeed) {
      setMode(LocationMode.highSpeed);
    } else if (speed < _lowSpeedThresholdMs && _currentMode == LocationMode.highSpeed) {
      setMode(LocationMode.performance);
    }
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

    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: interval,
      );
    } else if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
      );
    }

    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }

  void _restartStream() {
    _subscription?.cancel();
    _startStream();
  }

  void stop() {
    _isRunning = false;
    _subscription?.cancel();
    _subscription = null;
    _positionController.close();
    _positionController = StreamController<Position>.broadcast();
    _currentMode = LocationMode.economy;
  }
}
