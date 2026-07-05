import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/gps_point.dart';

enum LocationMode { economy, performance, highSpeed }

const double _highSpeedThresholdMs = 20 / 3.6;
const double _lowSpeedThresholdMs = 15 / 3.6;

const _kMethodChannel = MethodChannel('com.pavelbotsu.velocity/location');
const _kEventChannel = EventChannel('com.pavelbotsu.velocity/location_events');

class LocationService {
  StreamController<GpsPoint> _gpsController =
      StreamController<GpsPoint>.broadcast();
  StreamSubscription<Position>? _geoSub;
  StreamSubscription<dynamic>? _eventSub;
  LocationMode _currentMode = LocationMode.economy;
  bool _isRunning = false;

  Stream<GpsPoint> get gpsPointStream => _gpsController.stream;
  LocationMode get currentMode => _currentMode;

  Future<void> start() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'GPS is turned off. '
        'Please enable Location in your device Settings.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. '
        'Enable it under Settings → Apps → Velocity → Permissions.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was denied.');
    }

    _isRunning = true;

    if (Platform.isAndroid) {
      await _startAndroid();
    } else {
      _startIos();
    }
  }

  Future<void> _startAndroid() async {
    await _kMethodChannel.invokeMethod<void>('startService');
    _eventSub = _kEventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (_gpsController.isClosed) return;
        try {
          final point =
              GpsPoint.fromNativeMap(Map<Object?, Object?>.from(event as Map));
          _gpsController.add(point);
          _autoAdjustMode(point.speedKmh / 3.6);
        } catch (_) {}
      },
      onError: (Object error) {
        if (!_gpsController.isClosed) _gpsController.addError(error);
      },
    );
  }

  void _startIos() {
    final settings = _getIosSettings();
    _geoSub =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (Position pos) {
        if (_gpsController.isClosed) return;
        final point = GpsPoint.fromPosition(pos);
        _gpsController.add(point);
        _autoAdjustMode(pos.speed);
      },
      onError: (Object error) {
        if (!_gpsController.isClosed) _gpsController.addError(error);
      },
    );
  }

  void _autoAdjustMode(double speedMs) {
    if (speedMs > _highSpeedThresholdMs &&
        _currentMode != LocationMode.highSpeed) {
      _currentMode = LocationMode.highSpeed;
      if (!Platform.isAndroid) _restartIos();
    } else if (speedMs < _lowSpeedThresholdMs &&
        _currentMode == LocationMode.highSpeed) {
      _currentMode = LocationMode.performance;
      if (!Platform.isAndroid) _restartIos();
    }
  }

  void setMode(LocationMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      if (_isRunning && !Platform.isAndroid) _restartIos();
    }
  }

  void _restartIos() {
    _geoSub?.cancel();
    _startIos();
  }

  AppleSettings _getIosSettings() {
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      activityType: ActivityType.fitness,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
    );
  }

  /// Updates the text shown in the persistent "ride in progress" foreground
  /// notification (Android only; no-op elsewhere).
  Future<void> updateNotification(String text) async {
    if (!Platform.isAndroid) return;
    try {
      await _kMethodChannel
          .invokeMethod<void>('updateNotification', {'text': text});
    } catch (_) {}
  }

  void stop() {
    _isRunning = false;

    _geoSub?.cancel();
    _geoSub = null;

    if (Platform.isAndroid) {
      _eventSub?.cancel();
      _eventSub = null;
      _kMethodChannel.invokeMethod<void>('stopService');
    }

    _gpsController.close();
    _gpsController = StreamController<GpsPoint>.broadcast();
    _currentMode = LocationMode.economy;
  }
}
