import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/trip_service.dart';
import '../models/trip.dart';
import 'package:drive_tracker/components/trip_card.dart';
import 'login_page.dart';
import 'live_trip_page.dart';
import 'package:drive_tracker/services/location_service.dart';
import 'package:drive_tracker/screens/trip_summary_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late TripService _tripService;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final authService = context.read<AuthService>();
      if (authService.currentUser != null) {
        _tripService = TripService(
          authService.currentUser!.uid,
          context.read<LocationService>(),
        );
        await _loadTrips();
      }
    } catch (e) {
      print('Error initializing services: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadTrips() async {
    try {
      await _tripService.loadTrips();
    } catch (e) {
      print('Error loading trips: $e');
    }
  }

  Future<void> _startNewTrip(BuildContext context) async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LiveTripPage()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting trip: $e')),
        );
      }
    }
  }

  void _viewTripDetails(BuildContext context, Trip trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripSummaryPage(trip: trip),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await context.read<AuthService>().signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to logout: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final userName = user?.fullName ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Welcome, $userName!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Start tracking your trips today',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _startNewTrip(context),
              icon: const Icon(Icons.directions_car),
              label: const Text('Start New Trip'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Recent Trips',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: _tripService.recentTrips.isEmpty
                  ? const Center(
                child: Text('No trips recorded yet'),
              )
                  : ListView.builder(
                itemCount: _tripService.recentTrips.length,
                itemBuilder: (context, index) {
                  final trip = _tripService.recentTrips[index];
                  return TripCard(
                    trip: trip,
                    onTap: () => _viewTripDetails(context, trip),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startNewTrip(context),
        icon: const Icon(Icons.add),
        label: const Text('New Trip'),
      ),
    );
  }
}