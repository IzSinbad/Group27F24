import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../models/trip.dart';
import 'package:drive_tracker/SQLite Database Helper.dart';
import 'location_service.dart';
import 'package:latlong2/latlong.dart';
class TripService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  final LocationService _locationService;
  final String _userId;

  List<Trip> _recentTrips = [];
  List<Trip> get recentTrips => _recentTrips;

  String? _currentTripId;
  List<LatLng> _currentRoutePoints = [];
  List<SpeedWarning> _currentWarnings = [];
  double _currentMaxSpeed = 0;
  double _currentDistance = 0;
  DateTime? _tripStartTime;

  // Speed threshold for warnings (km/h)
  static const double speedLimit = 50.0;

  TripService(this._userId, this._locationService);

  Future<void> startTrip() async {
    if (_currentTripId != null) {
      throw Exception('A trip is already in progress');
    }

    try {
      final startPosition = await _locationService.getCurrentLocation();
      _tripStartTime = DateTime.now();
      _currentTripId = const Uuid().v4();


      final startLatLng = LatLng(startPosition.latitude, startPosition.longitude);
      _currentRoutePoints.add(startLatLng);

      final trip = Trip(
        id: _currentTripId!,
        userId: _userId,
        startTime: _tripStartTime!,
        distance: 0,
        averageSpeed: 0,
        maxSpeed: 0,
        startLocation: startLatLng,
        routePoints: [startLatLng],
        warnings: [],
        status: 'active',
      );

      await _db.insertTrip(trip);
      _startLocationTracking();
      notifyListeners();
    } catch (e) {
      _currentTripId = null;
      _tripStartTime = null;
      _currentRoutePoints.clear();
      throw Exception('Failed to start trip: $e');
    }
  }

  void _startLocationTracking() {
    try {
      _locationService.startLocationUpdates((position) {
        _handleLocationUpdate(position);
      });
    } catch (e) {
      throw Exception('Failed to start location tracking: $e');
    }
  }

  void _handleLocationUpdate(Position position) {
    if (_currentTripId == null) return;


    final newPoint = LatLng(position.latitude, position.longitude);


    final currentSpeed = position.speed * 3.6;


    if (currentSpeed > _currentMaxSpeed) {
      _currentMaxSpeed = currentSpeed;
    }


    _currentRoutePoints.add(newPoint);


    if (_currentRoutePoints.length >= 2) {
      final lastPoint = _currentRoutePoints[_currentRoutePoints.length - 2];
      final distanceInMeters = Geolocator.distanceBetween(
        lastPoint.latitude,
        lastPoint.longitude,
        newPoint.latitude,
        newPoint.longitude,
      );
      _currentDistance += distanceInMeters / 1000; // Convert to kilometers
    }


    if (currentSpeed > speedLimit) {
      _currentWarnings.add(SpeedWarning(
        timestamp: DateTime.now(),
        speed: currentSpeed,
        speedLimit: speedLimit,
        location: newPoint,
      ));
    }


    _updateTripData();


    notifyListeners();
  }

  Future<void> _updateTripData() async {
    try {
      if (_currentTripId == null) return;

      final trip = Trip(
        id: _currentTripId!,
        userId: _userId,
        startTime: _tripStartTime!,
        distance: _currentDistance,
        averageSpeed: _calculateAverageSpeed(),
        maxSpeed: _currentMaxSpeed,
        warnings: _currentWarnings,
        startLocation: _currentRoutePoints.first,
        routePoints: _currentRoutePoints,
        status: 'active',
      );

      await _db.updateTrip(trip);
    } catch (e) {
      print('Error updating trip data: $e');
    }
  }

  double _calculateAverageSpeed() {
    if (_tripStartTime == null) return 0;

    final duration = DateTime.now().difference(_tripStartTime!);
    if (duration.inSeconds == 0) return 0;

    // Calculate average speed in km/h
    return (_currentDistance / duration.inSeconds) * 3600;
  }

  Future<Trip> endTrip() async {
    if (_currentTripId == null) {
      throw Exception('No active trip to end');
    }

    try {
      final endTime = DateTime.now();
      final endPosition = await _locationService.getCurrentLocation();

      final duration = endTime.difference(_tripStartTime!);
      final averageSpeed = duration.inSeconds > 0
          ? (_currentDistance / duration.inSeconds) * 3600
          : 0.0;

      final trip = Trip(
        id: _currentTripId!,
        userId: _userId,
        startTime: _tripStartTime!,
        endTime: endTime,
        distance: _currentDistance,
        averageSpeed: averageSpeed,
        maxSpeed: _currentMaxSpeed,
        warnings: _currentWarnings,
        startLocation: _currentRoutePoints.first,
        endLocation: LatLng(endPosition.latitude, endPosition.longitude),
        routePoints: _currentRoutePoints,
        status: 'completed',
      );

      await _db.updateTrip(trip);
      _cleanupTrip();
      return trip;
    } catch (e) {
      throw Exception('Failed to end trip: $e');
    }
  }
  Future<void> loadTrips() async {
    try {
      _recentTrips = await _db.getTripsForUser(_userId);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to load trips: $e');
    }
  }

  void _cleanupTrip() {
    _currentTripId = null;
    _currentRoutePoints.clear();
    _currentWarnings.clear();
    _currentMaxSpeed = 0;
    _currentDistance = 0;
    _tripStartTime = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _cleanupTrip();
    super.dispose();
  }
}