import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ride.dart';

class RideHistoryService extends ChangeNotifier {
  static final RideHistoryService instance = RideHistoryService._();

  RideHistoryService._();

  static const String _key = 'ride_history';

  Future<void> saveRide(Ride ride) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    existing.insert(0, jsonEncode(ride.toJson()));
    await prefs.setStringList(_key, existing);
    notifyListeners();
  }

  Future<List<Ride>> loadRides() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => Ride.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteRide(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final rides = await loadRides();
    rides.removeWhere((r) => r.id == id);
    await prefs.setStringList(
      _key,
      rides.map((r) => jsonEncode(r.toJson())).toList(),
    );
    notifyListeners();
  }
}
