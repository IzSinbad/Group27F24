import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:developer' as dev;
import 'services/auth_service.dart';
import 'services/location_service.dart';
import 'services/trip_service.dart';
import 'screens/start_page.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Create and initialize services
    final authService = AuthService();
    final locationService = LocationService();

    try {

      await Future.wait([
        authService.initialize(),
        locationService.initialize(),
      ]);

      runApp(
        MultiProvider(
          providers: [

            ChangeNotifierProvider<AuthService>.value(
              value: authService,
            ),

            // Location Service Provider
            ChangeNotifierProvider<LocationService>.value(
              value: locationService,
            ),


            ChangeNotifierProxyProvider<AuthService, TripService>(
              // Create initial instance
              create: (context) => TripService(
                '',
                locationService,
              ),

              update: (context, auth, previousService) {
                if (auth.currentUser == null) {

                  previousService?.dispose();
                  return TripService('', locationService);
                }


                if (previousService != null &&
                    previousService.userId == auth.currentUser!.uid) {
                  return previousService;
                }


                previousService?.dispose();
                return TripService(
                  auth.currentUser!.uid,
                  locationService,
                );
              },
            ),
          ],
          child: const MyApp(),
        ),
      );
    } catch (e, stack) {
      dev.log(
        'Failed to initialize app',
        error: e,
        stackTrace: stack,
        name: 'Main',
      );
      runApp(MaterialApp(
        home: _buildErrorScreen(e.toString()),
      ));
    }
  }, (error, stack) {
    dev.log(
      'Uncaught error in app',
      error: error,
      stackTrace: stack,
      name: 'Main',
    );
  });
}

Widget _buildErrorScreen(String error) {
  return Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to initialize app: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => main(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drive Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const StartPage(),
    );
  }
}