import 'package:latlong2/latlong.dart';

class Trip {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final double distance;
  final double averageSpeed;
  final double maxSpeed;
  final double currentSpeed;
  final List<SpeedWarning> warnings;
  final LatLng startLocation;
  final LatLng? endLocation;
  final List<LatLng> routePoints;
  final String status;

  Trip({
    required this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    required this.distance,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.currentSpeed,
    required this.warnings,
    required this.startLocation,
    this.endLocation,
    required this.routePoints,
    required this.status,
  });

  // Create a Trip from database map
  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'],
      userId: map['userId'],
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime']),
      endTime: map['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime'])
          : null,
      distance: map['distance'].toDouble(),
      averageSpeed: map['averageSpeed'].toDouble(),
      maxSpeed: map['maxSpeed'].toDouble(),
      currentSpeed: map['currentSpeed']?.toDouble() ?? 0.0,
      warnings: (map['warnings'] as List)
          .map((w) => SpeedWarning.fromMap(w))
          .toList(),
      startLocation: LatLng(
        map['startLatitude'].toDouble(),
        map['startLongitude'].toDouble(),
      ),
      endLocation: map['endLatitude'] != null
          ? LatLng(
        map['endLatitude'].toDouble(),
        map['endLongitude'].toDouble(),
      )
          : null,
      routePoints: (map['routePoints'] as List).map((point) => LatLng(
        point['latitude'].toDouble(),
        point['longitude'].toDouble(),
      )).toList(),
      status: map['status'],
    );
  }


  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'distance': distance,
      'averageSpeed': averageSpeed,
      'maxSpeed': maxSpeed,
      'currentSpeed': currentSpeed,
      'warnings': warnings.map((w) => w.toMap()).toList(),
      'startLatitude': startLocation.latitude,
      'startLongitude': startLocation.longitude,
      'endLatitude': endLocation?.latitude,
      'endLongitude': endLocation?.longitude,
      'routePoints': routePoints.map((point) => {
        'latitude': point.latitude,
        'longitude': point.longitude,
      }).toList(),
      'status': status,
    };
  }


  Trip copyWith({
    String? id,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    double? distance,
    double? averageSpeed,
    double? maxSpeed,
    double? currentSpeed,
    List<SpeedWarning>? warnings,
    LatLng? startLocation,
    LatLng? endLocation,
    List<LatLng>? routePoints,
    String? status,
  }) {
    return Trip(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distance: distance ?? this.distance,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      warnings: warnings ?? this.warnings,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      routePoints: routePoints ?? this.routePoints,
      status: status ?? this.status,
    );
  }

  // Helper methods for trip statistics
  Duration get duration => endTime?.difference(startTime) ??
      DateTime.now().difference(startTime);

  double get averageSpeedKmh => averageSpeed * 3.6;
  double get maxSpeedKmh => maxSpeed * 3.6;
  double get currentSpeedKmh => currentSpeed * 3.6;

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  // Calculate trip metrics
  double get distanceInKm => distance;

  int get totalWarnings => warnings.length;

  bool get hasSpeedWarnings => warnings.isNotEmpty;

  // Get the last recorded position
  LatLng get currentLocation => routePoints.isEmpty ? startLocation : routePoints.last;
}

class SpeedWarning {
  final DateTime timestamp;
  final double speed;
  final double speedLimit;
  final LatLng location;

  SpeedWarning({
    required this.timestamp,
    required this.speed,
    required this.speedLimit,
    required this.location,
  });

  factory SpeedWarning.fromMap(Map<String, dynamic> map) {
    return SpeedWarning(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      speed: map['speed'].toDouble(),
      speedLimit: map['speedLimit'].toDouble(),
      location: LatLng(
        map['latitude'].toDouble(),
        map['longitude'].toDouble(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'speed': speed,
      'speedLimit': speedLimit,
      'latitude': location.latitude,
      'longitude': location.longitude,
    };
  }

  // Helper methods
  double get speedKmh => speed * 3.6;  // Convert m/s to km/h
  double get speedLimitKmh => speedLimit * 3.6;  // Convert m/s to km/h
  double get speedExcess => speed - speedLimit;  // In m/s
  double get speedExcessKmh => speedExcess * 3.6;  // In km/h
}