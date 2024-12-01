import 'package:flutter/material.dart';

// This class contains constant values used throughout the app
class AppConstants {
  // App theme colors
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color accentColor = Color(0xFF1976D2);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color warningColor = Color(0xFFFFA000);
  static const Color successColor = Color(0xFF388E3C);

  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Text styles
  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );

  static const TextStyle subheadingStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.25,
  );

  // Padding and spacing values
  static const double smallPadding = 8.0;
  static const double mediumPadding = 16.0;
  static const double largePadding = 24.0;

  // Border radius values
  static const double smallRadius = 4.0;
  static const double mediumRadius = 8.0;
  static const double largeRadius = 12.0;

  // Map configuration
  static const double defaultMapZoom = 15.0;
  static const double clusterZoom = 14.0;
  static const int mapAnimationDuration = 500;

  // Trip-related constants
  static const double defaultSpeedLimit = 50.0; // km/h
  static const double speedWarningThreshold = 5.0; // km/h over limit
  static const Duration minTripDuration = Duration(minutes: 1);
  static const double minTripDistance = 0.1; // kilometers

  // API-related timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration locationTimeout = Duration(seconds: 10);

  // Storage keys for SharedPreferences
  static const String userPrefsKey = 'user_preferences';
  static const String themePrefsKey = 'theme_preferences';
  static const String unitPrefsKey = 'unit_preferences';

  // File paths and names
  static const String reportDirectory = 'trip_reports';
  static const String reportPrefix = 'trip_report_';
  static const String reportExtension = '.pdf';

  // Error messages
  static const String genericError = 'An error occurred. Please try again.';
  static const String networkError = 'Please check your internet connection.';
  static const String locationError = 'Unable to access location services.';
  static const String storageError = 'Unable to access device storage.';
}