
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:developer' as dev;

class LocationService {
// Stream controllers
final _locationController = StreamController<Position>.broadcast();
StreamSubscription<Position>? _locationSubscription;

// Location tracking state
Position? _lastPosition;
bool _isTracking = false;
DateTime? _lastUpdateTime;

// Location validation parameters
static const int _minAccuracyMeters = 20;      // Minimum acceptable accuracy
static const int _maxAccuracyMeters = 100;     // Maximum acceptable accuracy
static const double _maxSpeedMps = 55.0;       // Maximum realistic speed (200 km/h)
static const int _locationTimeout = 15;         // Timeout for location requests
static const int _retryAttempts = 3;           // Number of retry attempts

// Public stream access
Stream<Position> get locationStream => _locationController.stream;

// Initialize location services with validation
Future<void> initializeLocation() async {
dev.log('Initializing location services...', name: 'LocationService');

// Check for mock locations
if (await _isMockLocationEnabled()) {
throw Exception('Please disable mock location settings in developer options');
}


await _validateLocationServices();


await _validateLocationAccuracy();
}


Future<bool> _isMockLocationEnabled() async {
try {
final position = await Geolocator.getCurrentPosition();
return position.isMocked;
} catch (e) {
dev.log('Error checking mock location: $e', name: 'LocationService');
return false;
}
}


Future<void> _validateLocationServices() async {
dev.log('Validating location services...', name: 'LocationService');


bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
if (!serviceEnabled) {
throw Exception(
'Location services are disabled. Please enable GPS in device settings.'
);
}


LocationPermission permission;
for (int i = 0; i < _retryAttempts; i++) {
permission = await Geolocator.checkPermission();

if (permission == LocationPermission.denied) {
permission = await Geolocator.requestPermission();
if (permission != LocationPermission.denied) break;
} else if (permission == LocationPermission.whileInUse ||
permission == LocationPermission.always) {
break;
}

if (i == _retryAttempts - 1) {
throw Exception('Location permission denied after multiple attempts');
}
await Future.delayed(const Duration(seconds: 1));
}
}

// Validate location accuracy
Future<void> _validateLocationAccuracy() async {
dev.log('Validating location accuracy...', name: 'LocationService');

Position? accuratePosition;

for (int i = 0; i < _retryAttempts; i++) {
try {
final position = await Geolocator.getCurrentPosition(
desiredAccuracy: LocationAccuracy.bestForNavigation,
forceAndroidLocationManager: true,
timeLimit: Duration(seconds: _locationTimeout),
);

if (position.accuracy <= _minAccuracyMeters) {
accuratePosition = position;
break;
}

dev.log(
'Attempt ${i + 1}: Accuracy ${position.accuracy}m not sufficient',
name: 'LocationService'
);

await Future.delayed(const Duration(seconds: 2));
} catch (e) {
dev.log('Error in accuracy validation: $e', name: 'LocationService');
}
}

if (accuratePosition == null) {
throw Exception(
'Unable to get accurate location. Please ensure you are outdoors with clear sky view.'
);
}
}

// Get current location with validation
Future<Position> getCurrentLocation() async {
dev.log('Getting current location...', name: 'LocationService');

try {
final position = await _getValidatedPosition();
_validatePosition(position);
return position;
} catch (e) {
dev.log('Error getting location: $e', name: 'LocationService');
throw Exception('Failed to get accurate location: $e');
}
}

// Get position with accuracy validation
Future<Position> _getValidatedPosition() async {
Position? validPosition;

for (int i = 0; i < _retryAttempts; i++) {
try {
final position = await Geolocator.getCurrentPosition(
desiredAccuracy: LocationAccuracy.bestForNavigation,
forceAndroidLocationManager: true,
timeLimit: Duration(seconds: _locationTimeout),
);

if (_isValidAccuracy(position)) {
validPosition = position;
break;
}

await Future.delayed(const Duration(seconds: 1));
} catch (e) {
dev.log('Attempt ${i + 1} failed: $e', name: 'LocationService');
}
}

if (validPosition == null) {
throw Exception('Failed to get accurate location after multiple attempts');
}

return validPosition;
}

// Validate position accuracy and movement
void _validatePosition(Position position) {
// Check for mock locations
if (position.isMocked) {
throw Exception('Mock location detected. Please disable mock locations.');
}

// Validate accuracy
if (!_isValidAccuracy(position)) {
throw Exception(
'Location accuracy (${position.accuracy}m) exceeds acceptable limit'
);
}

// Validate speed and movement
if (_lastPosition != null && _lastUpdateTime != null) {
final distance = Geolocator.distanceBetween(
_lastPosition!.latitude,
_lastPosition!.longitude,
position.latitude,
position.longitude,
);

final duration = DateTime.now().difference(_lastUpdateTime!).inSeconds;
if (duration > 0) {
final speed = distance / duration;
if (speed > _maxSpeedMps) {
throw Exception('Unrealistic movement detected');
}
}
}
}

// Check if accuracy is within acceptable range
bool _isValidAccuracy(Position position) {
return position.accuracy >= _minAccuracyMeters &&
position.accuracy <= _maxAccuracyMeters;
}

// Start location tracking with validation
Future<void> startLocationUpdates(Function(Position) onLocationUpdate) async {
if (_isTracking) return;

try {
await initializeLocation();
_lastPosition = await getCurrentLocation();

_locationSubscription = Geolocator.getPositionStream(
locationSettings: const LocationSettings(
accuracy: LocationAccuracy.bestForNavigation,
distanceFilter: 5,
timeLimit: Duration(seconds: 1),
),
).listen(
(position) => _handleLocationUpdate(position, onLocationUpdate),
onError: _handleLocationError,
);

_isTracking = true;
dev.log('Location tracking started', name: 'LocationService');
} catch (e) {
dev.log('Failed to start location tracking: $e', name: 'LocationService');
throw Exception('Failed to start location tracking: $e');
}
}

// Handle location updates with validation
void _handleLocationUpdate(Position position, Function(Position) onLocationUpdate) {
try {
_validatePosition(position);

_lastPosition = position;
_lastUpdateTime = DateTime.now();

_locationController.add(position);
onLocationUpdate(position);
} catch (e) {
dev.log('Invalid location update: $e', name: 'LocationService');
// Optionally notify the user or retry
}
}

void _handleLocationError(dynamic error) {
dev.log('Location stream error: $error', name: 'LocationService');
// Implement retry logic if needed
}

Future<void> stopLocationUpdates() async {
_isTracking = false;
await _locationSubscription?.cancel();
_locationSubscription = null;
_lastPosition = null;
_lastUpdateTime = null;
}

void dispose() {
stopLocationUpdates();
_locationController.close();
}

bool get isTracking => _isTracking;
Position? get lastPosition => _lastPosition;
}
