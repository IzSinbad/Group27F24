import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:developer' as dev;
import '../models/trip.dart';
import 'package:drive_tracker/SQLite Database Helper.dart';
import 'location_service.dart';

class TripService extends ChangeNotifier {
  // Dependencies
  final DatabaseHelper _db = DatabaseHelper();
  final LocationService _locationService;
  final String _userId;

  // Trip state management
  String? _currentTripId;        // ID of currently active trip
  DateTime? _tripStartTime;      // Start time of current trip
  List<LatLng> _currentRoutePoints = []; // Route points for current trip
  List<SpeedWarning> _currentWarnings = []; // Speed warnings for current trip
  double _currentMaxSpeed = 0;   // Maximum speed recorded in current trip
  double _currentDistance = 0;   // Total distance covered in current trip

  // Error and loading state
  String? _error;               // Current error message, if any
  bool _isLoading = false;      // Loading state indicator

  // Trip history
  List<Trip> _recentTrips = []; // List of user's recent trips

  // Getters
  List<Trip> get recentTrips => _recentTrips;
  bool get isTracking => _currentTripId != null;
  String? get error => _error;
  bool get isLoading => _isLoading;

  // Stream controller for real-time updates
  final _tripDataController = StreamController<Trip>.broadcast();
  Stream<Trip> get tripUpdates => _tripDataController.stream;

  TripService(this._userId, this._locationService) {
    _initializeService();
  }

  /// Initialize the service and load existing trips
  Future<void> _initializeService() async {
    try {
      _setLoading(true);
      await loadTrips();
    } catch (e) {
      _setError('Failed to initialize trip service: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Start a new trip with location tracking
  Future<void> startTrip() async {
    if (isTracking) {
      throw Exception('A trip is already in progress');
    }

    try {
      _setLoading(true);
      _clearError();

      // Initialize location tracking
      await _locationService.initialize();
      final startPosition = await _locationService.getCurrentLocation();

      // Create new trip
      _tripStartTime = DateTime.now();
      _currentTripId = const Uuid().v4();
      _currentRoutePoints = [
        LatLng(startPosition.latitude, startPosition.longitude)
      ];

      // Create initial trip record
      final trip = Trip(
        id: _currentTripId!,
        userId: _userId,
        startTime: _tripStartTime!,
        distance: 0,
        averageSpeed: 0,
        maxSpeed: 0,
        warnings: [],
        startLocation: _currentRoutePoints.first,
        routePoints: _currentRoutePoints,
        status: 'active',
      );

      // Save to database and start tracking
      await _db.insertTrip(trip);
      await _startLocationTracking();

      // Notify listeners of new trip
      _tripDataController.add(trip);
      notifyListeners();

    } catch (e) {
      _cleanup();
      _setError('Failed to start trip: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Start tracking location updates
  Future<void> _startLocationTracking() async {
    try {
      await _locationService.startLocationUpdates((position) {
        _handleLocationUpdate(position);
      });
    } catch (e) {
      throw Exception('Failed to start location tracking: $e');
    }
  }

  /// Handle incoming location updates
  void _handleLocationUpdate(Position position) {
    if (_currentTripId == null) return;

    try {
      final newPoint = LatLng(position.latitude, position.longitude);
      final currentSpeed = position.speed * 3.6; // Convert to km/h

      // Update trip data
      _currentRoutePoints.add(newPoint);
      if (currentSpeed > _currentMaxSpeed) {
        _currentMaxSpeed = currentSpeed;
      }

      // Calculate new distance
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

      // Check for speed warnings
      _checkSpeedWarning(currentSpeed, newPoint);

      // Update trip in database
      _updateTripData();

    } catch (e) {
      dev.log('Error handling location update: $e', name: 'TripService');
    }
  }

  /// Check and record speed warnings
  void _checkSpeedWarning(double currentSpeed, LatLng location) {
    const speedLimit = 50.0; // Example speed limit in km/h
    if (currentSpeed > speedLimit) {
      _currentWarnings.add(SpeedWarning(
        timestamp: DateTime.now(),
        speed: currentSpeed,
        speedLimit: speedLimit,
        location: location,
      ));
    }
  }

  /// Update trip data in database
  Future<void> _updateTripData() async {
    if (_currentTripId == null || _tripStartTime == null) return;

    try {
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
      _tripDataController.add(trip);
      notifyListeners();
    } catch (e) {
      dev.log('Error updating trip data: $e', name: 'TripService');
    }
  }

  /// Calculate average speed for the trip
  double _calculateAverageSpeed() {
    if (_tripStartTime == null) return 0;

    final duration = DateTime.now().difference(_tripStartTime!);
    if (duration.inSeconds == 0) return 0;

    return (_currentDistance / duration.inSeconds) * 3600; // Convert to km/h
  }

  /// End current trip and save final data
  Future<Trip> endTrip() async {
    if (_currentTripId == null) {
      throw Exception('No active trip to end');
    }

    try {
      _setLoading(true);
      final endPosition = await _locationService.getCurrentLocation();

      final trip = Trip(
        id: _currentTripId!,
        userId: _userId,
        startTime: _tripStartTime!,
        endTime: DateTime.now(),
        distance: _currentDistance,
        averageSpeed: _calculateAverageSpeed(),
        maxSpeed: _currentMaxSpeed,
        warnings: _currentWarnings,
        startLocation: _currentRoutePoints.first,
        endLocation: LatLng(endPosition.latitude, endPosition.longitude),
        routePoints: _currentRoutePoints,
        status: 'completed',
      );

      await _db.updateTrip(trip);
      await _locationService.stopLocationUpdates();

      _cleanup();
      await loadTrips();

      return trip;
    } catch (e) {
      _setError('Failed to end trip: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Load user's trips from database
  Future<void> loadTrips() async {
    try {
      _recentTrips = await _db.getTripsForUser(_userId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load trips: $e');
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error state
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error state
  void _clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clean up trip data
  void _cleanup() {
    _currentTripId = null;
    _tripStartTime = null;
    _currentRoutePoints.clear();
    _currentWarnings.clear();
    _currentMaxSpeed = 0;
    _currentDistance = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _tripDataController.close();
    super.dispose();
  }
}