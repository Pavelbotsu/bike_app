import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/bike_route.dart';
import '../models/gps_point.dart';
import '../models/ride.dart';
// LapSplit encode/decode helpers are on the LapSplit class itself

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'velocity.db');
    return openDatabase(
      path,
      version: 6,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE rides ADD COLUMN name TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE rides ADD COLUMN notes TEXT');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE rides ADD COLUMN laps_json TEXT');
        }
        if (oldVersion < 5) {
          await db.execute(_createRoutesTableSql);
          await db.execute(_createRoutePointsTableSql);
          await db.execute(_createRoutePointsIndexSql);
        }
        if (oldVersion < 6) {
          await db.execute('ALTER TABLE rides ADD COLUMN route_id TEXT');
        }
      },
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE rides (
            id TEXT PRIMARY KEY,
            name TEXT,
            notes TEXT,
            laps_json TEXT,
            route_id TEXT,
            start_time INTEGER NOT NULL,
            end_time INTEGER NOT NULL,
            distance_km REAL NOT NULL,
            duration_s INTEGER NOT NULL,
            avg_speed REAL NOT NULL,
            max_speed REAL NOT NULL,
            elevation_gain REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE gps_points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ride_id TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            speed_kmh REAL NOT NULL,
            altitude REAL NOT NULL,
            timestamp INTEGER NOT NULL,
            FOREIGN KEY (ride_id) REFERENCES rides(id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_gps_ride ON gps_points(ride_id)',
        );
        await db.execute(_createRoutesTableSql);
        await db.execute(_createRoutePointsTableSql);
        await db.execute(_createRoutePointsIndexSql);
      },
    );
  }

  static const _createRoutesTableSql = '''
    CREATE TABLE routes (
      id TEXT PRIMARY KEY,
      name TEXT,
      created_at INTEGER NOT NULL,
      distance_km REAL NOT NULL
    )
  ''';

  static const _createRoutePointsTableSql = '''
    CREATE TABLE route_points (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      route_id TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      seq INTEGER NOT NULL,
      FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE
    )
  ''';

  static const _createRoutePointsIndexSql =
      'CREATE INDEX idx_route_points_route ON route_points(route_id)';

  Future<void> saveRide(Ride ride) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.insert(
        'rides',
        {
          'id': ride.id,
          'name': ride.name,
          'notes': ride.notes,
          'laps_json': ride.laps.isEmpty ? null : LapSplit.encodeList(ride.laps),
          'route_id': ride.routeId,
          'start_time': ride.startTime.millisecondsSinceEpoch,
          'end_time': ride.endTime.millisecondsSinceEpoch,
          'distance_km': ride.distanceKm,
          'duration_s': ride.duration.inSeconds,
          'avg_speed': ride.avgSpeedKmh,
          'max_speed': ride.maxSpeedKmh,
          'elevation_gain': ride.elevationGainM,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final batch = txn.batch();
      for (final pt in ride.points) {
        batch.insert('gps_points', {
          'ride_id': ride.id,
          'latitude': pt.latitude,
          'longitude': pt.longitude,
          'speed_kmh': pt.speedKmh,
          'altitude': pt.altitude,
          'timestamp': pt.timestamp.millisecondsSinceEpoch,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Ride>> loadRides() async {
    final database = await db;
    final rows = await database.query(
      'rides',
      orderBy: 'start_time DESC',
    );
    final rides = <Ride>[];
    for (final row in rows) {
      final points = await _loadPoints(database, row['id'] as String);
      rides.add(_rideFromRow(row, points));
    }
    return rides;
  }

  Future<Ride> loadRideWithPoints(String id) async {
    final database = await db;
    final rows = await database.query('rides', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw StateError('Ride $id not found');
    final points = await _loadPoints(database, id);
    return _rideFromRow(rows.first, points);
  }

  Future<void> deleteRide(String id) async {
    final database = await db;
    await database.delete('rides', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> renameRide(String id, String name) async {
    final database = await db;
    await database.update(
      'rides',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<GpsPoint>> _loadPoints(Database database, String rideId) async {
    final rows = await database.query(
      'gps_points',
      where: 'ride_id = ?',
      whereArgs: [rideId],
      orderBy: 'timestamp ASC',
    );
    return rows
        .map((r) => GpsPoint(
              latitude: r['latitude'] as double,
              longitude: r['longitude'] as double,
              speedKmh: r['speed_kmh'] as double,
              altitude: r['altitude'] as double,
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                r['timestamp'] as int,
              ),
            ))
        .toList();
  }

  Future<void> updateNotes(String id, String notes) async {
    final database = await db;
    await database.update(
      'rides',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Ride _rideFromRow(Map<String, dynamic> row, List<GpsPoint> points) => Ride(
        id: row['id'] as String,
        name: row['name'] as String?,
        notes: row['notes'] as String?,
        laps: LapSplit.decodeList(row['laps_json'] as String?),
        routeId: row['route_id'] as String?,
        startTime:
            DateTime.fromMillisecondsSinceEpoch(row['start_time'] as int),
        endTime: DateTime.fromMillisecondsSinceEpoch(row['end_time'] as int),
        points: points,
      );

  Future<List<Ride>> loadRidesForRoute(String routeId) async {
    final database = await db;
    final rows = await database.query(
      'rides',
      where: 'route_id = ?',
      whereArgs: [routeId],
      orderBy: 'start_time DESC',
    );
    final rides = <Ride>[];
    for (final row in rows) {
      final points = await _loadPoints(database, row['id'] as String);
      rides.add(_rideFromRow(row, points));
    }
    return rides;
  }

  Future<void> saveRoute(BikeRoute route) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.insert(
        'routes',
        {
          'id': route.id,
          'name': route.name,
          'created_at': route.createdAt.millisecondsSinceEpoch,
          'distance_km': route.distanceKm,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Replace this route's points wholesale rather than diffing — routes
      // are small (a handful of waypoints), so this stays cheap and simple.
      await txn.delete('route_points', where: 'route_id = ?', whereArgs: [route.id]);
      final batch = txn.batch();
      for (int i = 0; i < route.waypoints.length; i++) {
        final wp = route.waypoints[i];
        batch.insert('route_points', {
          'route_id': route.id,
          'latitude': wp.latitude,
          'longitude': wp.longitude,
          'seq': i,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<BikeRoute>> loadRoutes() async {
    final database = await db;
    final rows = await database.query('routes', orderBy: 'created_at DESC');
    final routes = <BikeRoute>[];
    for (final row in rows) {
      final points = await _loadRoutePoints(database, row['id'] as String);
      routes.add(_routeFromRow(row, points));
    }
    return routes;
  }

  Future<BikeRoute> loadRouteWithPoints(String id) async {
    final database = await db;
    final rows =
        await database.query('routes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw StateError('Route $id not found');
    final points = await _loadRoutePoints(database, id);
    return _routeFromRow(rows.first, points);
  }

  Future<void> deleteRoute(String id) async {
    final database = await db;
    await database.transaction((txn) async {
      // FK enforcement is off (no PRAGMA foreign_keys=ON), so route_points
      // must be deleted explicitly instead of relying on ON DELETE CASCADE.
      await txn.delete('route_points', where: 'route_id = ?', whereArgs: [id]);
      await txn.delete('routes', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> renameRoute(String id, String name) async {
    final database = await db;
    await database.update(
      'routes',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LatLng>> _loadRoutePoints(
      Database database, String routeId) async {
    final rows = await database.query(
      'route_points',
      where: 'route_id = ?',
      whereArgs: [routeId],
      orderBy: 'seq ASC',
    );
    return rows
        .map((r) => LatLng(r['latitude'] as double, r['longitude'] as double))
        .toList();
  }

  BikeRoute _routeFromRow(Map<String, dynamic> row, List<LatLng> waypoints) =>
      BikeRoute(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        waypoints: waypoints,
      );
}
