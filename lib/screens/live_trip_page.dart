import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:developer' as dev;
import '../services/location_service.dart';
import '../services/trip_service.dart';
import '../components/error_display.dart';
import '../components/loading_indicator.dart';
import 'package:drive_tracker/models/trip.dart';
import 'package:drive_tracker/screens/trip_summary_page.dart';
class LiveTripPage extends StatefulWidget {
  const LiveTripPage({Key? key}) : super(key: key);

  @override
  State<LiveTripPage> createState() => _LiveTripPageState();
}

class _LiveTripPageState extends State<LiveTripPage> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  late LocationService _locationService;
  late TripService _tripService;

  // State management
  bool _isInitializing = true;
  String? _error;
  int _initializationAttempts = 0;
  static const int _maxInitAttempts = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    if (_initializationAttempts >= _maxInitAttempts) {
      _setError('Failed to initialize after multiple attempts');
      return;
    }

    setState(() {
      _isInitializing = true;
      _error = null;
    });

    try {
      dev.log('Initializing services...', name: 'LiveTripPage');

      _locationService = context.read<LocationService>();
      _tripService = context.read<TripService>();

      // Initialize location service with timeout
      await Future.any([
        _locationService.initialize(),
        Future.delayed(const Duration(seconds: 15))
            .then((_) => throw TimeoutException('Location initialization timed out')),
      ]);

      // Start trip only after successful initialization
      await _tripService.startTrip();

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _error = null;
        });
      }

    } catch (e) {
      _initializationAttempts++;
      _handleInitializationError(e);
    }
  }

  void _handleInitializationError(dynamic error) {
    String errorMessage = 'Failed to initialize trip';

    if (error is LocationServiceException) {
      switch (error.type) {
        case LocationErrorType.serviceDisabled:
          errorMessage = 'Please enable location services in settings';
          _showLocationSettingsDialog();
          break;
        case LocationErrorType.permissionDenied:
          errorMessage = 'Location permission is required for trip tracking';
          _showPermissionDialog();
          break;
        case LocationErrorType.permissionDeniedForever:
          errorMessage = 'Location permission permanently denied. Please enable in app settings';
          _showAppSettingsDialog();
          break;
        default:
          errorMessage = error.message;
      }
    }

    _setError(errorMessage);
  }

  void _setError(String message) {
    if (mounted) {
      setState(() {
        _error = message;
        _isInitializing = false;
      });
    }
  }

  Future<void> _showLocationSettingsDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Required'),
        content: const Text('Please enable location services to start tracking.'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
              if (mounted) {
                _initializeServices();
              }
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPermissionDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text('Location permission is needed to track your trip.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeServices();
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAppSettingsDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
            'Location permission is permanently denied. '
                'Please enable it in app settings.'
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openAppSettings();
              if (mounted) {
                _initializeServices();
              }
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        body: LoadingIndicator(
          message: 'Starting location services...',
          onRetry: _initializationAttempts < _maxInitAttempts
              ? _initializeServices
              : null,
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: ErrorDisplay(
          message: _error!,
          onRetry: _initializationAttempts < _maxInitAttempts
              ? _initializeServices
              : null,
        ),
      );
    }

    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        body: StreamBuilder<Trip>(
          stream: _tripService.tripUpdates,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorDisplay(
                message: 'Error updating trip: ${snapshot.error}',
                onRetry: _initializeServices,
              );
            }

            final trip = snapshot.data;
            if (trip == null) {
              return const LoadingIndicator(
                message: 'Preparing trip data...',
              );
            }

            return _buildTripContent(trip);
          },
        ),
      ),
    );
  }

  Widget _buildTripContent(Trip trip) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: trip.routePoints.last,
            initialZoom: 17,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: trip.routePoints,
                  color: Colors.blue,
                  strokeWidth: 4,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: trip.routePoints.last,
                  child: _buildLocationMarker(trip),
                ),
              ],
            ),
          ],
        ),
        _buildTripOverlay(trip),
      ],
    );
  }

  Widget _buildLocationMarker(Trip trip) {
    final position = _locationService.lastPosition;
    final heading = position?.heading ?? 0.0;

    return Transform.rotate(
      angle: (heading * (3.14159265359 / 180)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.navigation,
          color: Colors.blue,
          size: 30,
        ),
      ),
    );
  }

  Widget _buildTripOverlay(Trip trip) {
    return SafeArea(
      child: Column(
        children: [
          _buildSpeedDisplay(trip),
          const Spacer(),
          _buildTripStats(trip),
        ],
      ),
    );
  }

  Widget _buildSpeedDisplay(Trip trip) {
    final position = _locationService.lastPosition;
    final currentSpeed = position?.speed ?? 0.0;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  (currentSpeed * 3.6).toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
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

  Widget _buildTripStats(Trip trip) {
    final duration = trip.endTime?.difference(trip.startTime) ??
        DateTime.now().difference(trip.startTime);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
              _buildStatItem(
                icon: Icons.route,
                label: 'Distance',
                value: '${trip.distance.toStringAsFixed(1)} km',
              ),
              _buildStatItem(
                icon: Icons.timer,
                label: 'Duration',
                value: _formatDuration(duration),
              ),
              _buildStatItem(
                icon: Icons.speed,
                label: 'Max Speed',
                value: '${trip.maxSpeed.toStringAsFixed(1)} km/h',
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _handleEndTrip(),
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

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
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
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<bool> _handleBackPress() async {
    if (_tripService.isTracking) {
      final shouldEnd = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('End Trip?'),
          content: const Text('Do you want to end the current trip?'),
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

      if (shouldEnd ?? false) {
        await _handleEndTrip();
      }
      return false;
    }
    return true;
  }

  Future<void> _handleEndTrip() async {
    try {
      final trip = await _tripService.endTrip();
      if (mounted) {
        Navigator.pushReplacement(
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      // App going to background - pause location updates
        _locationService.stopLocationUpdates();
        break;
      case AppLifecycleState.resumed:
      // App coming to foreground - resume location updates
        if (_tripService.isTracking) {
          _initializeServices();
        }
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    super.dispose();
  }
}