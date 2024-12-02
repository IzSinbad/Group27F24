import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/trip_service.dart';
import 'login_page.dart';
import '../components/trip_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = false;

  // Handle sign out with proper BuildContext handling
  void _handleSignOut() async {
    if (!mounted) return;

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authService = context.read<AuthService>();

    setState(() => _isLoading = true);

    try {
      await authService.signOut();

      if (!mounted) return;

      // Navigate to login page after successful sign out
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

  void _startNewTrip() async {
    if (!mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final tripService = context.read<TripService?>();

    if (tripService == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Trip service not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Implement trip start logic here
      // await tripService.startTrip();
    } catch (e) {
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to start trip: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final tripService = context.watch<TripService?>();

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
              onPressed: _isLoading ? null : _handleSignOut,
            ),
        ],
      ),
      body: Padding(
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
                      'Welcome, ${user?.fullName ?? "User"}!',
                      style: Theme.of(context).textTheme.titleLarge,
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
              onPressed: _isLoading ? null : _startNewTrip,
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
              child: tripService?.recentTrips.isEmpty ?? true
                  ? const Center(
                child: Text('No trips recorded yet'),
              )
                  : ListView.builder(
                itemCount: tripService?.recentTrips.length ?? 0,
                itemBuilder: (context, index) {
                  final trip = tripService!.recentTrips[index];
                  return TripCard(
                    trip: trip,
                    onTap: () {
                      // Implement trip details navigation
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _startNewTrip,
        icon: const Icon(Icons.add),
        label: const Text('New Trip'),
      ),
    );
  }
}