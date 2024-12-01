import 'package:intl/intl.dart';
import '../models/trip.dart';

// Extensions provide additional functionality to existing classes
extension DateTimeExtensions on DateTime {

  String timeAgo() {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }


  String smartFormat() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(year, month, day);

    if (dateToCheck == today) {
      return 'Today ${DateFormat('HH:mm').format(this)}';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday ${DateFormat('HH:mm').format(this)}';
    } else {
      return DateFormat('MMM d, y HH:mm').format(this);
    }
  }
}

// Extension methods for Trip model to add calculated properties
extension TripExtensions on Trip {

  double get estimatedFuelConsumption {

    final baseConsumption = 7.5;
    final speedFactor = averageSpeed / 80.0;
    return (distance * baseConsumption * speedFactor) / 100;
  }

  // Calculate estimated CO2 emissions
  double get estimatedCO2Emissions {

    const emissionsPerLiter = 2.31;
    return estimatedFuelConsumption * emissionsPerLiter;
  }

  // Check if this trip had any safety concerns
  bool get hasSafetyConcerns {
    return warnings.isNotEmpty || maxSpeed > 120.0;
  }


  int get efficiencyScore {
    int score = 100;


    score -= warnings.length * 5;


    if (maxSpeed > averageSpeed * 1.5) {
      score -= 10;
    }


    if (averageSpeed > 110.0) {
      score -= 15;
    }

    return score.clamp(0, 100);
  }
}

// Extension to add formatting methods for numbers
extension NumberFormatting on num {

  String formatDistance() {
    if (this >= 1000) {
      return '${(this / 1000).toStringAsFixed(1)} km';
    } else {
      return '${toStringAsFixed(0)} m';
    }
  }

  // Format as speed with unit
  String formatSpeed() {
    return '${toStringAsFixed(1)} km/h';
  }


  String formatDuration() {
    final minutes = this ~/ 60;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours > 0) {
      return '$hours hr ${remainingMinutes > 0 ? '$remainingMinutes min' : ''}';
    } else {
      return '$minutes min';
    }
  }
}