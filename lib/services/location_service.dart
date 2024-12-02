import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:developer' as dev;

class LocationService extends ChangeNotifier {
  // Service state
  bool _isInitialized = false;
  bool _isTracking = false;
  Position? _lastPosition;
  String? _errorMessage;

  // Stream management
  final _locationController = StreamController<Position>.broadcast();
  StreamSubscription<Position>? _locationSubscription;
  Timer? _timeoutTimer;

  // Configuration constants
  static const int _timeoutSeconds = 15;
  static const int _retryAttempts = 3;
  static const double _minAccuracyMeters = 20.0;
  static const double _maxAccuracyMeters = 100.0;

  // Public getters
  bool get isInitialized => _isInitialized;
  bool get isTracking => _isTracking;
  Position? get lastPosition => _lastPosition;
  String? get errorMessage => _errorMessage;
  Stream<Position> get locationStream => _locationController.stream;

  // Initialize location services with proper error handling
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      dev.log('Starting location service initialization...', name: 'LocationService');

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationServiceException(
            'Location services are disabled. Please enable GPS.',
            LocationErrorType.serviceDisabled
        );
      }

      // Handle location permissions
      await _handleLocationPermission();

      // Test location accuracy
      await _verifyLocationAccuracy();

      _isInitialized = true;
      _errorMessage = null;
      notifyListeners();

      dev.log('Location service initialized successfully', name: 'LocationService');
    } catch (e) {
      _handleError('Failed to initialize location service: $e');
      rethrow;
    }
  }

  // Handle location permissions with retry logic
  Future<void> _handleLocationPermission() async {
    for (int attempt = 0; attempt < _retryAttempts; attempt++) {
      try {
        LocationPermission permission = await Geolocator.checkPermission();

        if (permission == LocationPermission.denied) {
          dev.log('Requesting location permission, attempt ${attempt + 1}',
              name: 'LocationService');

          permission = await Geolocator.requestPermission();

          if (permission == LocationPermission.denied) {
            if (attempt == _retryAttempts - 1) {
              throw LocationServiceException(
                  'Location permission denied',
                  LocationErrorType.permissionDenied
              );
            }
            continue;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          throw LocationServiceException(
              'Location permissions are permanently denied. Please enable in settings.',
              LocationErrorType.permissionDeniedForever
          );
        }

        return;
      } catch (e) {
        if (attempt == _retryAttempts - 1) rethrow;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  // Verify location accuracy
  Future<void> _verifyLocationAccuracy() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: _timeoutSeconds),
      );

      if (position.accuracy > _maxAccuracyMeters) {
        throw LocationServiceException(
            'Unable to get accurate location. Please ensure you are outdoors.',
            LocationErrorType.poorAccuracy
        );
      }

      _lastPosition = position;
    } on TimeoutException {
      throw LocationServiceException(
          'Location detection timed out. Please try again.',
          LocationErrorType.timeout
      );
    }
  }

  // Start location tracking with updates
  Future<void> startLocationUpdates(Function(Position) onLocationUpdate) async {
    if (!_isInitialized) await initialize();
    if (_isTracking) return;

    try {
      _isTracking = true;
      _startTimeoutTimer();

      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      ).listen(
            (position) {
          _resetTimeoutTimer();
          _lastPosition = position;
          _locationController.add(position);
          onLocationUpdate(position);
        },
        onError: (error) {
          _handleError('Location update error: $error');
        },
      );

      notifyListeners();
    } catch (e) {
      _isTracking = false;
      _handleError('Failed to start location updates: $e');
      rethrow;
    }
  }

  // Get current location with timeout
  Future<Position> getCurrentLocation() async {
    if (!_isInitialized) await initialize();

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: _timeoutSeconds),
      );

      _lastPosition = position;
      return position;
    } catch (e) {
      _handleError('Failed to get current location: $e');
      rethrow;
    }
  }

  // Handle timeout monitoring
  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(Duration(seconds: _timeoutSeconds), () {
      _handleError('Location updates timed out');
      stopLocationUpdates();
    });
  }

  void _resetTimeoutTimer() {
    if (_timeoutTimer?.isActive ?? false) {
      _timeoutTimer!.cancel();
      _startTimeoutTimer();
    }
  }

  // Error handling
  void _handleError(String message) {
    dev.log('Location error: $message', name: 'LocationService');
    _errorMessage = message;
    notifyListeners();
  }

  // Stop location updates
  Future<void> stopLocationUpdates() async {
    _isTracking = false;
    _timeoutTimer?.cancel();
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    notifyListeners();
  }

  // Cleanup resources
  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _locationSubscription?.cancel();
    _locationController.close();
    super.dispose();
  }
}

// Error handling types and exception
enum LocationErrorType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  poorAccuracy,
  unknown
}

class LocationServiceException implements Exception {
  final String message;
  final LocationErrorType type;

  LocationServiceException(this.message, this.type);

  @override
  String toString() => message;
}