import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ride.dart';
import 'database_service.dart';

class RideHistoryService extends ChangeNotifier {
  static final RideHistoryService instance = RideHistoryService._();
  RideHistoryService._();

  static const String _legacyKey = 'ride_history';
  bool _migrated = false;

  Future<void> saveRide(Ride ride) async {
    await _ensureMigrated();
    await DatabaseService.instance.saveRide(ride);
    notifyListeners();
  }

  Future<List<Ride>> loadRides() async {
    await _ensureMigrated();
    return DatabaseService.instance.loadRides();
  }

  Future<void> deleteRide(String id) async {
    await _ensureMigrated();
    await DatabaseService.instance.deleteRide(id);
    notifyListeners();
  }

  Future<void> renameRide(String id, String name) async {
    await _ensureMigrated();
    await DatabaseService.instance.renameRide(id, name);
    notifyListeners();
  }

  Future<void> updateNotes(String id, String notes) async {
    await _ensureMigrated();
    await DatabaseService.instance.updateNotes(id, notes);
    notifyListeners();
  }

  Future<void> _ensureMigrated() async {
    if (_migrated) return;
    _migrated = true;

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getStringList(_legacyKey);
    if (legacy == null || legacy.isEmpty) return;

    for (final raw in legacy) {
      try {
        final ride =
            Ride.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        await DatabaseService.instance.saveRide(ride);
      } catch (_) {}
    }
    await prefs.remove(_legacyKey);
  }
}
