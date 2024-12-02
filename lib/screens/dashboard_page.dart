import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/trip_service.dart';
import 'login_page.dart';
import 'live_trip_page.dart';
import '../components/error_display.dart';
import 'package:drive_tracker/models/user_data.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = false;

  Future<void> _startNewTrip() async {
    if (!mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final tripService = context.read<TripService?>();

    if (tripService == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Please sign in to start a trip'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await tripService.startTrip();

      if (!mounted) return;

      // Navigate to live trip page on success
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const LiveTripPage(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to start trip: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSignOut() async {
    if (!mounted) return;

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authService = context.read<AuthService>();

    setState(() => _isLoading = true);

    try {
      await authService.signOut();

      if (!mounted) return;

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to sign out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final tripService = context.watch<TripService?>();

    if (user == null) {
      return const LoginPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (_isLoading)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleSignOut,
            ),
        ],
      ),
      body: tripService == null
          ? const Center(
        child: ErrorDisplay(
          message: 'Trip service is not available',
          icon: Icons.error_outline,
        ),
      )
          : DashboardContent(
        user: user,
        tripService: tripService,
        onStartTrip: _startNewTrip,
        isLoading: _isLoading,
      ),
    );
  }
}

class DashboardContent extends StatelessWidget {
  final UserData user;
  final TripService tripService;
  final VoidCallback onStartTrip;
  final bool isLoading;

  const DashboardContent({
    Key? key,
    required this.user,
    required this.tripService,
    required this.onStartTrip,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                    'Welcome, ${user.fullName}!',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
            onPressed: isLoading ? null : onStartTrip,
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
            child: tripService.recentTrips.isEmpty
                ? const Center(
              child: Text('No trips recorded yet'),
            )
                : ListView.builder(
              itemCount: tripService.recentTrips.length,
              itemBuilder: (context, index) {
                final trip = tripService.recentTrips[index];
                return ListTile(
                  title: Text('Trip ${index + 1}'),
                  subtitle: Text(trip.startTime.toString()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}