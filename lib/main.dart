import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';
import 'package:drive_tracker/SQLite Database Helper.dart';
import 'screens/start_page.dart';
import 'package:drive_tracker/services/trip_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as dev;



Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  try {

    final locationService = LocationService();
    await locationService.initializeLocation();

    dev.log('Services initialized successfully', name: 'App Initialization');


    runApp(
      MultiProvider(
        providers: [

          ChangeNotifierProvider(
            create: (_) => AuthService(),
          ),

          Provider<LocationService>(
            create: (_) => locationService,
          ),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e, stackTrace) {
    dev.log(
      'Error during initialization',
      name: 'App Initialization',
      error: e,
      stackTrace: stackTrace,
    );
    // Even if initialization fails, start the app to show error state
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DriveTracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,

        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(),
        ),
      ),
      home: const StartPage(),
    );
  }
}