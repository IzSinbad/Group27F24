import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:developer' as dev;

class LocationService extends ChangeNotifier {
  bool _isInitialized = false;
  bool _isTracking = false;
  Position? _lastPosition;
  String? _error;
  StreamSubscription<Position>? _positionSubscription;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isTracking => _isTracking;
  Position? get lastPosition => _lastPosition;
  String? get error => _error;

  Future<void> initialize() async {
    try {
      dev.log('Initializing location service...', name: 'LocationService');

      // Request location permission explicitly
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      // Check if location is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Show dialog to enable location services
        throw Exception('Location services are disabled. Please enable location services in your device settings.');
      }

      // Enable background location updates if needed
      if (permission == LocationPermission.whileInUse) {
        permission = await Geolocator.requestPermission();
      }

      // Test getting location with high accuracy
      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      _isInitialized = true;
      notifyListeners();

      dev.log('Location service initialized successfully', name: 'LocationService');
    } catch (e) {
      _error = e.toString();
      dev.log('Failed to initialize location service: $e', name: 'LocationService');
      notifyListeners();
      rethrow;
    }
  }

  Future<Position> getCurrentLocation() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      _lastPosition = position;
      notifyListeners();
      return position;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> startLocationUpdates(Function(Position) onLocationUpdate) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      _isTracking = true;
      notifyListeners();

      // Configure location settings for better accuracy
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
        timeLimit: Duration(seconds: 3),
      );

      // Start location updates stream
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
            (Position position) {
          _lastPosition = position;
          onLocationUpdate(position);
          notifyListeners();
        },
        onError: (error) {
          dev.log('Location update error: $error', name: 'LocationService');
          _error = error.toString();
          notifyListeners();
        },
      );

    } catch (e) {
      _error = e.toString();
      _isTracking = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stopLocationUpdates() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopLocationUpdates();
    super.dispose();
  }
}