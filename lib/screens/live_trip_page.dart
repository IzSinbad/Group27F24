import 'package:drive_tracker/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/trip_service.dart';
import '../models/trip.dart';
import 'trip_summary_page.dart';
import 'dart:developer' as dev;

class LiveTripPage extends StatefulWidget {
  const LiveTripPage({Key? key}) : super(key: key);

  @override
  State<LiveTripPage> createState() => _LiveTripPageState();
}

class _LiveTripPageState extends State<LiveTripPage> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  bool _isEnding = false;
  Timer? _durationTimer;
  DateTime? _startTime;
  Position? _initialPosition;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTime = DateTime.now();
    _initializeLocation();
    _startDurationTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _durationTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _handlePopInvoked(bool didPop) {
    if (!didPop) {

      Future.microtask(() => _handleEndTrip());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeLocation();
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initializeLocation() async {
    try {
      final locationService = context.read<LocationService>();
      final position = await locationService.getCurrentLocation();

      if (mounted) {
        setState(() {
          _initialPosition = position;
          _isMapReady = true;
        });

        _mapController.move(
          LatLng(position.latitude, position.longitude),
          17.0,
        );
      }
    } catch (e) {
      dev.log('Failed to get initial location: $e', name: 'LiveTripPage');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to get current location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleEndTrip() async {
    if (_isEnding) return;

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final tripService = context.read<TripService>();

    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
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

    if (shouldEnd != true) return;

    setState(() => _isEnding = true);

    try {
      final trip = await tripService.endTrip();

      if (!mounted) return;

      await navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => TripSummaryPage(trip: trip),
        ),
      );
    } catch (e) {
      dev.log('Failed to end trip: $e', name: 'LiveTripPage');

      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to end trip: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isEnding = false);
      }
    }
  }

  String _formatDuration() {
    if (_startTime == null) return '0:00';
    final duration = DateTime.now().difference(_startTime!);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildMap(
      {required LatLng center, required List<LatLng> routePoints}) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 17,
        onMapReady: () {
          setState(() => _isMapReady = true);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.drive_tracker',
        ),
        if (routePoints.isNotEmpty) ...[
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: Colors.blue,
                strokeWidth: 4,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: routePoints.last,
                width: 50,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.navigation,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevents the default back navigation
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          // Handle the back button or pop action here
          _handleEndTrip();
        }
      },
      child: Scaffold(
        body: StreamBuilder<Trip>(
          stream: context.read<TripService>().tripUpdates,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}'),
              );
            }

            if (!_isMapReady) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final trip = snapshot.data;
            final currentLocation = _initialPosition != null
                ? LatLng(_initialPosition!.latitude, _initialPosition!.longitude)
                : const LatLng(0, 0);

            return Stack(
              children: [
                _buildMap(
                  center: trip?.routePoints.lastOrNull ?? currentLocation,
                  routePoints: trip?.routePoints ?? [],
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('Current Speed'),
                          Text(
                            '${((trip?.currentSpeed ?? 0) * 3.6).toStringAsFixed(1)} km/h',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 88,
                  left: 16,
                  right: 16,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat(
                            'Distance',
                            '${(trip?.distance ?? 0).toStringAsFixed(2)} km',
                            Icons.route,
                          ),
                          _buildStat(
                            'Duration',
                            _formatDuration(),
                            Icons.timer,
                          ),
                          _buildStat(
                            'Max Speed',
                            '${((trip?.maxSpeed ?? 0) * 3.6).toStringAsFixed(1)} km/h',
                            Icons.speed,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    onPressed: _isEnding ? null : _handleEndTrip,
                    backgroundColor: Colors.red,
                    child: _isEnding
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(Icons.stop),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
  }
