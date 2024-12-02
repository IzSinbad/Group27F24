import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'package:latlong2/latlong.dart';
import '../models/trip.dart';
import '../models/user_data.dart';

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
      version: 2,  // Increased version number for schema update
      onCreate: _createDb,
      onUpgrade: _onUpgrade,
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

    // Updated trips table with currentSpeed
    await db.execute('''
      CREATE TABLE trips(
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        startTime INTEGER NOT NULL,
        endTime INTEGER,
        distance REAL NOT NULL DEFAULT 0,
        averageSpeed REAL NOT NULL DEFAULT 0,
        maxSpeed REAL NOT NULL DEFAULT 0,
        currentSpeed REAL NOT NULL DEFAULT 0,
        startLatitude REAL NOT NULL,
        startLongitude REAL NOT NULL,
        endLatitude REAL,
        endLongitude REAL,
        status TEXT NOT NULL,
        FOREIGN KEY(userId) REFERENCES users(id)
      )
    ''');

    // Route points table
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

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add currentSpeed column to trips table
      await db.execute('ALTER TABLE trips ADD COLUMN currentSpeed REAL NOT NULL DEFAULT 0');
    }
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
      'currentSpeed': trip.currentSpeed,
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

  Future<void> updateTrip(Trip trip) async {
    final db = await database;
    await db.update(
      'trips',
      {
        'endTime': trip.endTime?.millisecondsSinceEpoch,
        'distance': trip.distance,
        'averageSpeed': trip.averageSpeed,
        'maxSpeed': trip.maxSpeed,
        'currentSpeed': trip.currentSpeed,
        'endLatitude': trip.endLocation?.latitude,
        'endLongitude': trip.endLocation?.longitude,
        'status': trip.status,
      },
      where: 'id = ?',
      whereArgs: [trip.id],
    );
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
    currentSpeed: tripMap['currentSpeed'] ?? 0.0,
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

  Future<Trip> getTrip(String tripId) async {
    final db = await database;

    // Get trip data
    final tripMap = await db.query(
      'trips',
      where: 'id = ?',
      whereArgs: [tripId],
    );

    if (tripMap.isEmpty) {
      throw Exception('Trip not found: $tripId');
    }

    // Get route points
    final routePoints = await db.query(
      'route_points',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp ASC', // Ensure points are in chronological order
    );

    // Get speed warnings
    final warnings = await db.query(
      'speed_warnings',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp ASC',
    );

    return _constructTripFromMaps(tripMap.first, routePoints, warnings);
  }

  Future<List<Trip>> getTripsForUser(String userId) async {
    final db = await database;

    // Get all trips for user
    final trips = await db.query(
      'trips',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'startTime DESC', // Most recent first
    );

    // Build list of trips with their associated data
    List<Trip> tripList = [];
    for (var tripMap in trips) {
      final routePoints = await db.query(
        'route_points',
        where: 'tripId = ?',
        whereArgs: [tripMap['id']],
        orderBy: 'timestamp ASC',
      );

      final warnings = await db.query(
        'speed_warnings',
        where: 'tripId = ?',
        whereArgs: [tripMap['id']],
        orderBy: 'timestamp ASC',
      );

      tripList.add(_constructTripFromMaps(tripMap, routePoints, warnings));
    }

    return tripList;
  }

  Future<void> deleteTrip(String tripId) async {
    final db = await database;

    // Use transaction to ensure all related data is deleted
    await db.transaction((txn) async {
      // Delete related data first (due to foreign key constraints)
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

      // Finally delete the trip itself
      await txn.delete(
        'trips',
        where: 'id = ?',
        whereArgs: [tripId],
      );
    });
  }

  // User Operations
  Future<void> insertUser(UserData user, String password) async {
    final db = await database;
    await db.insert('users', {
      'id': user.uid,
      'fullName': user.fullName,
      'email': user.email,
      'password': password, // Note: In production, this should be hashed
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

  Future<void> updateUserProfile(UserData user) async {
    final db = await database;
    await db.update(
      'users',
      {
        'fullName': user.fullName,
        'email': user.email,
      },
      where: 'id = ?',
      whereArgs: [user.uid],
    );
  }

  Future<void> deleteUser(String userId) async {
    final db = await database;

    // Use transaction to handle cascade deletion
    await db.transaction((txn) async {
      // Get all trips for user
      final trips = await txn.query(
        'trips',
        columns: ['id'],
        where: 'userId = ?',
        whereArgs: [userId],
      );

      // Delete all trip data
      for (var trip in trips) {
        final tripId = trip['id'] as String;
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
        await txn.delete(
          'trips',
          where: 'id = ?',
          whereArgs: [tripId],
        );
      }

      // Finally delete the user
      await txn.delete(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );
    });
  }

  // Cleanup and maintenance methods
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('route_points');
      await txn.delete('speed_warnings');
      await txn.delete('trips');
      await txn.delete('users');
    });
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}