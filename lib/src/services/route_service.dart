import 'package:flutter/foundation.dart';
import '../models/bike_route.dart';
import 'database_service.dart';

class RouteService extends ChangeNotifier {
  static final RouteService instance = RouteService._();
  RouteService._();

  Future<void> saveRoute(BikeRoute route) async {
    await DatabaseService.instance.saveRoute(route);
    notifyListeners();
  }

  Future<List<BikeRoute>> loadRoutes() {
    return DatabaseService.instance.loadRoutes();
  }

  Future<BikeRoute> loadRouteWithPoints(String id) {
    return DatabaseService.instance.loadRouteWithPoints(id);
  }

  Future<void> deleteRoute(String id) async {
    await DatabaseService.instance.deleteRoute(id);
    notifyListeners();
  }

  Future<void> renameRoute(String id, String name) async {
    await DatabaseService.instance.renameRoute(id, name);
    notifyListeners();
  }
}
