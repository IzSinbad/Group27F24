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
    if (_isInitialized) return;

    try {
      dev.log('Initializing location service...', name: 'LocationService');

      // First checking if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Try to get initial position with timeout
      try {
        _lastPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 5));
      } catch (e) {
        dev.log('Error getting initial position: $e', name: 'LocationService');
        // Don't throw here
      }

      _isInitialized = true;
      notifyListeners();
      dev.log('Location service initialized successfully', name: 'LocationService');

    } catch (e, stack) {
      _error = e.toString();
      dev.log(
        'Failed to initialize location service',
        error: e,
        stackTrace: stack,
        name: 'LocationService',
      );
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
      ).timeout(const Duration(seconds: 5));

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

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

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