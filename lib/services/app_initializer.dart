import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:developer' as dev;
import 'auth_service.dart';
import 'location_service.dart';

class InitializationStep {
  final String message;
  final double progress;

  const InitializationStep(this.message, this.progress);
}

class InitializedServices {
  final AuthService authService;
  final LocationService locationService;
  final SharedPreferences preferences;

  InitializedServices({
    required this.authService,
    required this.locationService,
    required this.preferences,
  });
}

class AppInitializer {
  InitializationStep _currentStep = const InitializationStep('Starting...', 0.0);
  bool _isInitialized = false;
  String? _error;

  InitializationStep get currentStep => _currentStep;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  Future<InitializedServices> initializeServices() async {
    final stopwatch = Stopwatch()..start();

    try {
      // Initialize shared preferences
      _updateStep('Initializing storage...', 0.2);
      final prefs = await SharedPreferences.getInstance();

      // Initialize auth service
      _updateStep('Initializing authentication...', 0.5);
      final authService = AuthService();
      await authService.initialize();

      // Initialize location service
      _updateStep('Setting up location services...', 0.7);
      final locationService = LocationService();
      await locationService.initialize();

      // Final checks
      _updateStep('Performing final checks...', 0.9);
      _isInitialized = true;

      stopwatch.stop();
      dev.log(
        'App initialization completed in ${stopwatch.elapsedMilliseconds}ms',
        name: 'AppInitializer',
      );

      return InitializedServices(
        authService: authService,
        locationService: locationService,
        preferences: prefs,
      );

    } catch (e, stack) {
      dev.log(
        'Initialization failed at step: ${_currentStep.message}',
        error: e,
        stackTrace: stack,
        name: 'AppInitializer',
      );
      _error = e.toString();
      rethrow;
    }
  }

  void _updateStep(String message, double progress) {
    _currentStep = InitializationStep(message, progress);
    dev.log(
      'Initialization step: $message (${(progress * 100).toStringAsFixed(0)}%)',
      name: 'AppInitializer',
    );
  }
}

