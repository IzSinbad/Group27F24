import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'package:latlong2/latlong.dart';
import '../models/trip.dart';
import 'package:drive_tracker/models/user_data.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'drive_tracker.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users(
        id TEXT PRIMARY KEY,
        fullName TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        joinDate INTEGER NOT NULL
      )
    ''');

    // Trips table
    await db.execute('''
      CREATE TABLE trips(
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        startTime INTEGER NOT NULL,
        endTime INTEGER,
        distance REAL NOT NULL DEFAULT 0,
        averageSpeed REAL NOT NULL DEFAULT 0,
        maxSpeed REAL NOT NULL DEFAULT 0,
        startLatitude REAL NOT NULL,
        startLongitude REAL NOT NULL,
        endLatitude REAL,
        endLongitude REAL,
        status TEXT NOT NULL,
        FOREIGN KEY(userId) REFERENCES users(id)
      )
    ''');

    // Route points table for storing trip paths
    await db.execute('''
      CREATE TABLE route_points(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tripId TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY(tripId) REFERENCES trips(id)
      )
    ''');

    // Speed warnings table
    await db.execute('''
      CREATE TABLE speed_warnings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tripId TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        speed REAL NOT NULL,
        speedLimit REAL NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        FOREIGN KEY(tripId) REFERENCES trips(id)
      )
    ''');
  }

  // User Operations
  Future<void> insertUser(UserData user, String password) async {
    final db = await database;
    await db.insert('users', {
      'id': user.uid,
      'fullName': user.fullName,
      'email': user.email,
      'password': password, // In production, ensure this is hashed
      'joinDate': user.joinDate.millisecondsSinceEpoch
    });
  }

  Future<UserData?> getUserByEmail(String email, String password) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );

    if (maps.isEmpty) return null;

    return UserData(
      uid: maps.first['id'],
      fullName: maps.first['fullName'],
      email: maps.first['email'],
      joinDate: DateTime.fromMillisecondsSinceEpoch(maps.first['joinDate']),
    );
  }

  // Trip Operations
  Future<String> insertTrip(Trip trip) async {
    final db = await database;
    await db.insert('trips', {
      'id': trip.id,
      'userId': trip.userId,
      'startTime': trip.startTime.millisecondsSinceEpoch,
      'endTime': trip.endTime?.millisecondsSinceEpoch,
      'distance': trip.distance,
      'averageSpeed': trip.averageSpeed,
      'maxSpeed': trip.maxSpeed,
      'startLatitude': trip.startLocation.latitude,
      'startLongitude': trip.startLocation.longitude,
      'endLatitude': trip.endLocation?.latitude,
      'endLongitude': trip.endLocation?.longitude,
      'status': trip.status,
    });

    // Insert route points
    for (LatLng point in trip.routePoints) {
      await db.insert('route_points', {
        'tripId': trip.id,
        'latitude': point.latitude,
        'longitude': point.longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    // Insert speed warnings
    for (SpeedWarning warning in trip.warnings) {
      await db.insert('speed_warnings', {
        'tripId': trip.id,
        'timestamp': warning.timestamp.millisecondsSinceEpoch,
        'speed': warning.speed,
        'speedLimit': warning.speedLimit,
        'latitude': warning.location.latitude,
        'longitude': warning.location.longitude,
      });
    }

    return trip.id;
  }

  Future<Trip> getTrip(String tripId) async {
    final db = await database;

    final tripMap = await db.query(
      'trips',
      where: 'id = ?',
      whereArgs: [tripId],
    );

    if (tripMap.isEmpty) throw Exception('Trip not found');

    // Get route points
    final routePoints = await db.query(
      'route_points',
      where: 'tripId = ?',
      whereArgs: [tripId],
    );

    // Get speed warnings
    final warnings = await db.query(
      'speed_warnings',
      where: 'tripId = ?',
      whereArgs: [tripId],
    );

    return _constructTripFromMaps(tripMap.first, routePoints, warnings);
  }

  Trip _constructTripFromMaps(
      Map<String, dynamic> tripMap,
      List<Map<String, dynamic>> routePoints,
      List<Map<String, dynamic>> warnings,
      ) {
    return Trip(
      id: tripMap['id'],
      userId: tripMap['userId'],
      startTime: DateTime.fromMillisecondsSinceEpoch(tripMap['startTime']),
      endTime: tripMap['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(tripMap['endTime'])
          : null,
      distance: tripMap['distance'],
      averageSpeed: tripMap['averageSpeed'],
      maxSpeed: tripMap['maxSpeed'],
      startLocation: LatLng(tripMap['startLatitude'], tripMap['startLongitude']),
      endLocation: tripMap['endLatitude'] != null
          ? LatLng(tripMap['endLatitude'], tripMap['endLongitude'])
          : null,
      routePoints: routePoints
          .map((point) => LatLng(point['latitude'], point['longitude']))
          .toList(),
      warnings: warnings
          .map((w) => SpeedWarning(
        timestamp: DateTime.fromMillisecondsSinceEpoch(w['timestamp']),
        speed: w['speed'],
        speedLimit: w['speedLimit'],
        location: LatLng(w['latitude'], w['longitude']),
      ))
          .toList(),
      status: tripMap['status'],
    );
  }

  Future<List<Trip>> getTripsForUser(String userId) async {
    final db = await database;
    final trips = await db.query(
      'trips',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'startTime DESC',
    );

    List<Trip> tripList = [];
    for (var tripMap in trips) {
      final routePoints = await db.query(
        'route_points',
        where: 'tripId = ?',
        whereArgs: [tripMap['id']],
      );

      final warnings = await db.query(
        'speed_warnings',
        where: 'tripId = ?',
        whereArgs: [tripMap['id']],
      );

      tripList.add(_constructTripFromMaps(tripMap, routePoints, warnings));
    }

    return tripList;
  }

  Future<void> updateTrip(Trip trip) async {
    final db = await database;
    await db.update(
      'trips',
      {
        'endTime': trip.endTime?.millisecondsSinceEpoch,
        'distance': trip.distance,
        'averageSpeed': trip.averageSpeed,
        'maxSpeed': trip.maxSpeed,
        'endLatitude': trip.endLocation?.latitude,
        'endLongitude': trip.endLocation?.longitude,
        'status': trip.status,
      },
      where: 'id = ?',
      whereArgs: [trip.id],
    );
  }

  Future<void> deleteTrip(String tripId) async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete related records first
      await txn.delete(
        'route_points',
        where: 'tripId = ?',
        whereArgs: [tripId],
      );
      await txn.delete(
        'speed_warnings',
        where: 'tripId = ?',
        whereArgs: [tripId],
      );
      // Delete the trip
      await txn.delete(
        'trips',
        where: 'id = ?',
        whereArgs: [tripId],
      );
    });
  }
}