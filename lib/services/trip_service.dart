import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:developer' as dev;
import '../models/trip.dart';
import 'package:drive_tracker/SQLite Database Helper.dart';
import 'location_service.dart';
import 'package:drive_tracker/services/location_service.dart';
class TripService extends ChangeNotifier {
  final String userId;
  final LocationService _locationService;
  final DatabaseHelper _db = DatabaseHelper();


  // State variables
  bool _isDisposed = false;
  final List<Trip> _recentTrips = [];
  String? _currentTripId;
  DateTime? _tripStartTime;
  final List<LatLng> _routePoints = [];  // Keep as final but modify contents
  bool _isLoading = false;
  String? _error;
  double _currentDistance = 0;
  double _maxSpeed = 0;
  double _currentSpeed = 0;
  final List<SpeedWarning> _speedWarnings = [];
  Position? _lastPosition;
  DateTime? _lastUpdateTime;

  // Stream controller for real-time updates
  final _tripUpdateController = StreamController<Trip>.broadcast();


  // Getters
  bool get isTracking => _currentTripId != null;
  Stream<Trip> get tripUpdates => _tripUpdateController.stream;
  List<Trip> get recentTrips => List.unmodifiable(_recentTrips);
  bool get isLoading => _isLoading;
  String? get error => _error;

  TripService(this.userId, this._locationService) {
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await loadTrips();
      dev.log('TripService initialized successfully', name: 'TripService');
    } catch (e) {
      dev.log('Failed to initialize TripService: $e', name: 'TripService');
      _error = 'Failed to initialize: $e';
      notifyListeners();
    }
  }

  Future<void> startTrip() async {
    if (isTracking) {
      throw Exception('A trip is already in progress');
    }

    try {
      _setLoading(true);

      // Get initial location
      final startPosition = await _locationService.getCurrentLocation();

      // Initialize trip
      _currentTripId = const Uuid().v4();
      _tripStartTime = DateTime.now();

      // Clear existing points and add initial position
      _routePoints.clear();
      _routePoints.add(LatLng(startPosition.latitude, startPosition.longitude));

      _lastPosition = startPosition;
      _lastUpdateTime = _tripStartTime;

      final trip = Trip(
        id: _currentTripId!,
        userId: userId,
        startTime: _tripStartTime!,
        distance: 0,
        averageSpeed: 0,
        maxSpeed: 0,
        currentSpeed: 0,
        warnings: [],
        startLocation: _routePoints.first,
        routePoints: _routePoints,
        status: 'active',
      );

      // Save to database
      await _db.insertTrip(trip);

      // Start location tracking
      await _startLocationTracking();

      // Emit initial state
      _tripUpdateController.add(trip);
      notifyListeners();

    } catch (e) {
      _error = 'Failed to start trip: $e';
      _resetTripState();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      await _locationService.startLocationUpdates(_handleLocationUpdate);
    } catch (e) {
      dev.log('Failed to start location tracking: $e', name: 'TripService');
      throw Exception('Failed to start location tracking: $e');
    }
  }

  void _handleLocationUpdate(Position position) {
    if (_isDisposed || !isTracking) return;

    try {
      final now = DateTime.now();
      final newPoint = LatLng(position.latitude, position.longitude);

      // Update speed (convert from m/s to km/h)
      _currentSpeed = position.speed * 3.6;  // Convert to km/h
      if (_currentSpeed > _maxSpeed) {
        _maxSpeed = _currentSpeed;
      }

      // Calculate distance if we have a previous point
      if (_lastPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        _currentDistance += distance / 1000; // Convert to kilometers
      }

      _routePoints.add(newPoint);
      _lastPosition = position;
      _lastUpdateTime = now;

      // Check speed limits
      _checkSpeedWarning(_currentSpeed, newPoint);

      // Create updated trip object
      final trip = Trip(
        id: _currentTripId!,
        userId: userId,
        startTime: _tripStartTime!,
        distance: _currentDistance,
        averageSpeed: _calculateAverageSpeed(),
        maxSpeed: _maxSpeed,
        currentSpeed: _currentSpeed,
        warnings: _speedWarnings,
        startLocation: _routePoints.first,
        routePoints: _routePoints,
        status: 'active',
      );

      // Emit update
      if (!_isDisposed) {
        _tripUpdateController.add(trip);
      }

      // Update database asynchronously
      _db.updateTrip(trip).catchError((e) {
        dev.log('Error updating trip in database: $e', name: 'TripService');
      });
    } catch (e) {
      dev.log('Error handling location update: $e', name: 'TripService');
    }
  }
  double _calculateAverageSpeed() {
    if (_tripStartTime == null || _lastUpdateTime == null) return 0;

    final duration = _lastUpdateTime!.difference(_tripStartTime!);
    if (duration.inSeconds == 0) return 0;

    // Calculate speed in km/h
    return (_currentDistance / duration.inHours);
  }


  void _checkSpeedWarning(double speedInMs, LatLng location) {
    const speedLimitKmh = 50.0;
    final speedKmh = speedInMs * 3.6;

    if (speedKmh > speedLimitKmh) {
      _speedWarnings.add(SpeedWarning(
        timestamp: DateTime.now(),
        speed: speedInMs,  // Store in m/s
        speedLimit: speedLimitKmh / 3.6,  // Convert to m/s
        location: location,
      ));
    }
  }


  void _resetTripState() {
    _currentTripId = null;
    _tripStartTime = null;
    _routePoints.clear();  // Properly clear the final list
    _currentDistance = 0;
    _maxSpeed = 0;
    _currentSpeed = 0;
    _speedWarnings.clear();
    _lastPosition = null;
    _lastUpdateTime = null;
    notifyListeners();
  }

  Future<void> loadTrips() async {
    if (_isDisposed) return;

    try {
      _setLoading(true);
      final trips = await _db.getTripsForUser(userId);
      _recentTrips
        ..clear()
        ..addAll(trips);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load trips: $e';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }
  Future<Trip> endTrip() async {
    if (!isTracking) {
      throw Exception('No active trip to end');
    }

    try {
      _setLoading(true);

      // Get final location
      final endPosition = await _locationService.getCurrentLocation();
      final endTime = DateTime.now();

      // Create final trip record
      final trip = Trip(
        id: _currentTripId!,
        userId: userId,
        startTime: _tripStartTime!,
        endTime: endTime,
        distance: _currentDistance,
        averageSpeed: _calculateAverageSpeed(),
        maxSpeed: _maxSpeed,
        currentSpeed: 0,
        warnings: _speedWarnings,
        startLocation: _routePoints.first,
        endLocation: LatLng(endPosition.latitude, endPosition.longitude),
        routePoints: List.from(_routePoints),
        status: 'completed',
      );

      // Update database
      await _db.updateTrip(trip);

      // Stop location tracking
      await _locationService.stopLocationUpdates();

      // Reset state
      _resetTripState();

      // Reload trips
      await loadTrips();

      return trip;
    } catch (e) {
      dev.log('Failed to end trip: $e', name: 'TripService');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }


  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    _locationService.stopLocationUpdates();
    _tripUpdateController.close();
    super.dispose();
  }
}