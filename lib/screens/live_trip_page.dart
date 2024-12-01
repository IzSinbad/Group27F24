
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math' as math;
import '../services/trip_service.dart';
import '../services/location_service.dart';
import 'trip_summary_page.dart';

/// A page that handles real-time trip tracking with location updates,
/// map visualization, and trip statistics.
class LiveTripPage extends StatefulWidget {
const LiveTripPage({Key? key}) : super(key: key);

@override
State<LiveTripPage> createState() => _LiveTripPageState();
}

class _LiveTripPageState extends State<LiveTripPage> with WidgetsBindingObserver {
// Controllers and services
final MapController _mapController = MapController();
late LocationService _locationService;
late TripService _tripService;
StreamSubscription<Position>? _locationSubscription;

// Location tracking
Position? _currentPosition;
final List<LatLng> _routePoints = [];
bool _isFirstLocation = true;

// Trip statistics
double _currentSpeed = 0.0;
double _maxSpeed = 0.0;
double _distance = 0.0;
Duration _elapsed = Duration.zero;
Timer? _timer;

// State management
bool _isTripActive = false;
bool _isInitialized = false;
bool _showingExitDialog = false;
String _initializationStatus = 'Starting location services...';

// Location validation constants
static const int _maxRetryAttempts = 3;
static const double _minAccuracyMeters = 20.0;
static const double _maxSpeedKmh = 200.0;

@override
void initState() {
super.initState();
WidgetsBinding.instance.addObserver(this);
initializeLocationTracking();
}

/// Initializes location tracking and services
  Future<void> initializeLocationTracking() async {
    dev.log('Starting location initialization...', name: 'LiveTripPage');
    try {
      // Initialize services first
      _locationService = context.read<LocationService>();
      _tripService = context.read<TripService>();

      // Ensure location services are ready
      await ensureLocationServicesReady();

      // Get initial location with retries
      updateStatus('Getting initial location...');
      for (int i = 0; i < 3; i++) {
        try {
          await getInitialLocation();
          break;
        } catch (e) {
          if (i == 2) rethrow;
          dev.log('Retrying location initialization...', name: 'LiveTripPage');
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (mounted) {
        setState(() => _isInitialized = true);
        await startTrip();
      }
    } catch (e) {
      handleInitializationError(e);
    }
  }

/// Validates location services and permissions
Future<void> validateLocationServices() async {
updateStatus('Checking location services...');

bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
if (!serviceEnabled) {
if (mounted) {
await showDialog(
context: context,
barrierDismissible: false,
builder: (context) => AlertDialog(
title: const Text('Location Services Disabled'),
content: const Text('Please enable GPS to continue tracking.'),
actions: [
TextButton(
onPressed: () {
Navigator.pop(context);
Geolocator.openLocationSettings();
},
child: const Text('Open Settings'),
),
],
),
);
}
throw Exception('Location services are disabled');
}

LocationPermission permission = await Geolocator.checkPermission();
if (permission == LocationPermission.denied) {
permission = await Geolocator.requestPermission();
if (permission == LocationPermission.denied) {
throw Exception('Location permission denied');
}
}

if (permission == LocationPermission.deniedForever) {
if (mounted) {
await showDialog(
context: context,
barrierDismissible: false,
builder: (context) => AlertDialog(
title: const Text('Location Permission Required'),
content: const Text(
'Please enable location permission in app settings.',
),
actions: [
TextButton(
onPressed: () {
Navigator.pop(context);
Geolocator.openAppSettings();
},
child: const Text('Open Settings'),
),
],
),
);
}
throw Exception('Location permissions permanently denied');
}
}

/// Gets initial location with emulator handling
Future<void> getInitialLocation() async {
updateStatus('Getting initial location...');

final deviceInfo = DeviceInfoPlugin();
final androidInfo = await deviceInfo.androidInfo;
final isEmulator = !androidInfo.isPhysicalDevice;

if (isEmulator) {
dev.log('Running on emulator', name: 'LiveTripPage');
await Geolocator.getCurrentPosition(
desiredAccuracy: LocationAccuracy.best,
);
}

for (int attempt = 0; attempt < _maxRetryAttempts; attempt++) {
try {
updateStatus('Attempt ${attempt + 1} to get location...');
final position = await _locationService.getCurrentLocation();

if (validateLocationAccuracy(position)) {
setState(() {
_currentPosition = position;
_routePoints.add(LatLng(position.latitude, position.longitude));
});
return;
}

await Future.delayed(const Duration(seconds: 1));
} catch (e) {
dev.log('Location attempt failed: $e', name: 'LiveTripPage');
}
}

throw Exception('Could not get accurate location');
}

/// Validates location accuracy
bool validateLocationAccuracy(Position position) {
if (position.accuracy > _minAccuracyMeters) return false;
if (position.speed * 3.6 > _maxSpeedKmh) return false;
if (position.isMocked) return false;
return true;
}

/// Updates initialization status
void updateStatus(String message) {
if (mounted) {
setState(() => _initializationStatus = message);
}
dev.log(message, name: 'LiveTripPage');
}

/// Handles initialization errors
void handleInitializationError(Object error) {
dev.log('Initialization error: $error', name: 'LiveTripPage');
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(error.toString()),
backgroundColor: Colors.red,
action: SnackBarAction(
label: 'Retry',
onPressed: initializeLocationTracking,
textColor: Colors.white,
),
),
);
}
}

/// Starts trip tracking
Future<void> startTrip() async {
try {
await _tripService.startTrip();
setState(() => _isTripActive = true);

_timer = Timer.periodic(
const Duration(seconds: 1),
(timer) => setState(() => _elapsed = Duration(seconds: timer.tick)),
);

startLocationTracking();
} catch (e) {
throw Exception('Failed to start trip: $e');
}
}

/// Starts continuous location tracking
void startLocationTracking() {
_locationSubscription = Geolocator.getPositionStream(
locationSettings: const LocationSettings(
accuracy: LocationAccuracy.bestForNavigation,
distanceFilter: 5,
timeLimit: Duration(seconds: 1),
),
).listen(
handleLocationUpdate,
onError: (error) {
dev.log('Location error: $error', name: 'LiveTripPage');
},
);
}

/// Handles location updates
void handleLocationUpdate(Position position) {
if (!mounted || !_isTripActive) return;

if (!validateLocationAccuracy(position)) {
dev.log('Invalid location update', name: 'LiveTripPage');
return;
}

setState(() {
_currentPosition = position;

// Update speed with smoothing
final newSpeed = position.speed * 3.6;
_currentSpeed = _currentSpeed * 0.3 + newSpeed * 0.7;

if (newSpeed > _maxSpeed && newSpeed <= _maxSpeedKmh) {
_maxSpeed = newSpeed;
}

// Update route
final newPoint = LatLng(position.latitude, position.longitude);
_routePoints.add(newPoint);

// Calculate distance
if (_routePoints.length >= 2) {
final lastPoint = _routePoints[_routePoints.length - 2];
final distance = const Distance().as(
LengthUnit.Kilometer,
lastPoint,
newPoint,
);

if (distance < 0.1) {
_distance += distance;
}
}

// Update map
if (_isFirstLocation) {
_mapController.move(newPoint, 17);
_isFirstLocation = false;
} else {
_mapController.moveAndRotate(
newPoint,
_mapController.camera.zoom,
position.heading,
);
}
});
}

/// Ends the current trip
Future<void> endTrip() async {
if (!_isTripActive || _showingExitDialog) return;

setState(() => _showingExitDialog = true);

final shouldEnd = await showDialog<bool>(
context: context,
barrierDismissible: false,
builder: (context) => AlertDialog(
title: const Text('End Trip?'),
content: const Text('Are you sure you want to end this trip?'),
actions: [
TextButton(
onPressed: () => Navigator.pop(context, false),
child: const Text('Cancel'),
),
TextButton(
onPressed: () => Navigator.pop(context, true),
child: const Text('End Trip'),
),
],
),
);

setState(() => _showingExitDialog = false);

if (shouldEnd == true) {
try {
final trip = await _tripService.endTrip();

await cleanup();

if (mounted) {
await Navigator.pushReplacement(
context,
MaterialPageRoute(
builder: (_) => TripSummaryPage(trip: trip),
),
);
}
} catch (e) {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Error ending trip: $e'),
backgroundColor: Colors.red,
),
);
}
}
}
}
// Add this new method to handle service connections
  Future<void> ensureLocationServicesReady() async {
    dev.log('Ensuring location services are ready...', name: 'LiveTripPage');

    try {
      // First, check if device location is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          // Show a more user-friendly dialog explaining why location is needed
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Location Required'),
              content: const Text(
                'This app needs location access to track your trip. '
                    'Please enable location services in your device settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    // Open location settings and wait for user to return
                    await Geolocator.openLocationSettings();
                    // Check again after user returns
                    if (mounted) {
                      await ensureLocationServicesReady();
                    }
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
        throw Exception('Location services are not enabled');
      }

      // Then, handle permissions with better error recovery
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Show explanation before requesting permission
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Location Permission Needed'),
              content: const Text(
                'This app needs location permission to track your trip. '
                    'Please grant permission when prompted.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }

        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      // Handle permanent denial case
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Location Permission Required'),
              content: const Text(
                'Location permission is permanently denied. '
                    'Please enable it in app settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Geolocator.openAppSettings();
                    if (mounted) {
                      await ensureLocationServicesReady();
                    }
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
        throw Exception('Location permissions are permanently denied');
      }

      // Finally, test the location service with a timeout
      try {
        await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('Location request timed out'),
        );
      } catch (e) {
        dev.log('Error testing location service: $e', name: 'LiveTripPage');
        rethrow;
      }

    } catch (e) {
      dev.log('Error ensuring location services: $e', name: 'LiveTripPage');
      rethrow;
    }
  }
/// Cleans up resources
Future<void> cleanup() async {
_locationSubscription?.cancel();
_timer?.cancel();
setState(() => _isTripActive = false);
}

@override
Widget build(BuildContext context) {
if (!_isInitialized || _currentPosition == null) {
return Scaffold(
body: Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
const CircularProgressIndicator(),
const SizedBox(height: 16),
Text(
_initializationStatus,
textAlign: TextAlign.center,
),
const SizedBox(height: 16),
TextButton(
onPressed: initializeLocationTracking,
child: const Text('Retry'),
),
],
),
),
);
}

return PopScope(
canPop: false,
onPopInvoked: (didPop) async {
if (didPop) return;
await endTrip();
},
child: Scaffold(
body: Stack(
children: [
buildMap(),
buildOverlay(),
],
),
),
);
}

/// Builds the map widget
Widget buildMap() {
return FlutterMap(
mapController: _mapController,
options: MapOptions(
initialCenter: LatLng(
_currentPosition!.latitude,
_currentPosition!.longitude,
),
initialZoom: 17,
interactionOptions: const InteractionOptions(
enableScrollWheel: true,
enableMultiFingerGestureRace: true,
),
),
children: [
buildMapLayers(),
],
);
}

/// Builds map layers
Widget buildMapLayers() {
return Stack(
children: [
TileLayer(
urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
userAgentPackageName: 'com.example.drive_tracker',
maxZoom: 19,
),
if (_routePoints.isNotEmpty)
PolylineLayer(
polylines: [
Polyline(
points: _routePoints,
color: Colors.blue,
strokeWidth: 4,
),
],
),
MarkerLayer(
markers: [
Marker(
point: LatLng(
_currentPosition!.latitude,
_currentPosition!.longitude,
),
width: 50,
height: 50,
child: Container(
decoration: BoxDecoration(
color: Colors.blue.withOpacity(0.3),
shape: BoxShape.circle,
),
child: Transform.rotate(
angle: (_currentPosition?.heading ?? 0) * math.pi / 180,
child: const Icon(
Icons.navigation,
color: Colors.blue,
size: 30,
),
),
),
),
],
),
],
);
}

/// Builds UI overlay
Widget buildOverlay() {
return SafeArea(
child: Column(
children: [
Padding(
padding: const EdgeInsets.all(16.0),
child: buildSpeedCard(),
),
const Spacer(),
buildBottomStats(),
],
),
);
}

/// Builds speed display card
Widget buildSpeedCard() {
return Card(
elevation: 8,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
),
child: Padding(
padding: const EdgeInsets.all(16.0),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
const Text(
'Current Speed',
style: TextStyle(color: Colors.grey),
),
Row(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.end,
children: [
Text(
_currentSpeed.toStringAsFixed(1),
style: const TextStyle(
fontSize: 48,
fontWeight: FontWeight.bold,
),
),
const Padding(
padding: EdgeInsets.only(bottom: 8.0),
child: Text(
' km/h',
style: TextStyle(
fontSize: 16,
color: Colors.grey,
),
),
),
],
),
],
),
),
);
}
/// Builds bottom statistics container
Widget buildBottomStats() {
return Container(
margin: const EdgeInsets.all(16),
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(16),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(0.1),
blurRadius: 10,
offset: const Offset(0, -5),
),
],
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceAround,
children: [
buildStat(
label: 'Distance',
value: formatDistance(_distance),
icon: Icons.route,
),
buildStat(
label: 'Duration',
value: formatDuration(_elapsed),
icon: Icons.timer,
),
buildStat(
label: 'Max Speed',
value: '${_maxSpeed.toStringAsFixed(1)}\nkm/h',
icon: Icons.speed,
),
],
),
const SizedBox(height: 16),
ElevatedButton(
onPressed: _isTripActive ? endTrip : null,
style: ElevatedButton.styleFrom(
backgroundColor: Colors.red,
minimumSize: const Size(double.infinity, 50),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
),
child: const Text('End Trip'),
),
],
),
);
}

/// Builds individual stat display
Widget buildStat({
required String label,
required String value,
required IconData icon,
}) {
return Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(icon, color: Colors.blue),
const SizedBox(height: 4),
Text(
label,
style: const TextStyle(
color: Colors.grey,
fontSize: 12,
),
),
Text(
value,
textAlign: TextAlign.center,
style: const TextStyle(
fontWeight: FontWeight.bold,
fontSize: 16,
),
),
],
);
}

/// Formats duration to minutes:seconds
String formatDuration(Duration duration) {
String twoDigits(int n) => n.toString().padLeft(2, '0');
final minutes = duration.inMinutes;
final seconds = duration.inSeconds.remainder(60);
return '$minutes:${twoDigits(seconds)}';
}

/// Formats distance to appropriate unit
String formatDistance(double distanceInKm) {
final meters = (distanceInKm * 1000).round();
if (distanceInKm >= 1) {
return '${distanceInKm.toStringAsFixed(1)} km\n($meters m)';
} else {
return '$meters m';
}
}

/// Handles app lifecycle changes
@override
Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
dev.log('App lifecycle state changed to: $state', name: 'LiveTripPage');

switch (state) {
case AppLifecycleState.paused:
_locationSubscription?.pause();
_timer?.cancel();
break;

case AppLifecycleState.resumed:
if (_isTripActive) {
_locationSubscription?.resume();
_timer?.cancel();
_timer = Timer.periodic(
const Duration(seconds: 1),
(timer) => setState(() => _elapsed = Duration(seconds: timer.tick)),
);
await refreshLocation();
}
break;

case AppLifecycleState.detached:
await cleanup();
break;

default:
break;
}
}

/// Refreshes current location
Future<void> refreshLocation() async {
try {
await getInitialLocation();
if (mounted && _currentPosition != null) {
_mapController.move(
LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
_mapController.camera.zoom,
);
}
} catch (e) {
dev.log('Error refreshing location: $e', name: 'LiveTripPage');
}
}

/// Cleans up resources when disposing
@override
void dispose() {
WidgetsBinding.instance.removeObserver(this);
cleanup();
_mapController.dispose();
super.dispose();
}
}