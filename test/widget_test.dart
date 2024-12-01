import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drive_tracker/main.dart';
import 'package:drive_tracker/services/auth_service.dart';
import 'package:drive_tracker/services/trip_service.dart';
import 'package:drive_tracker/services/location_service.dart';
import 'package:drive_tracker/models/user_data.dart';
import 'package:drive_tracker/models/trip.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Custom test implementation of AuthService for testing
class TestAuthService extends AuthService {
  bool isSignedIn = false;
  User? _mockUser;

  @override
  User? get currentUser => _mockUser;

  @override
  Future<UserData> signIn({
    required String email,
    required String password,
  }) async {
    // Simulate successful sign in
    isSignedIn = true;
    notifyListeners();

    return UserData(
      uid: 'test-uid',
      fullName: 'Test User',
      email: email,
      joinDate: DateTime.now(),
    );
  }

  @override
  Future<UserData> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    isSignedIn = true;
    notifyListeners();

    return UserData(
      uid: 'test-uid',
      fullName: fullName,
      email: email,
      joinDate: DateTime.now(),
    );
  }

  @override
  Future<void> signOut() async {
    isSignedIn = false;
    _mockUser = null;
    notifyListeners();
  }

  @override
  Future<void> resetPassword(String email) async {
    // Implementation not needed for basic tests
  }
}

// Custom test implementation of LocationService for testing
class TestLocationService extends LocationService {
  @override
  Future<Position> getCurrentLocation() async {
    // Return a mock position with all required parameters
    return Position(
      latitude: 0,
      longitude: 0,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }

  @override
  Future<void> startLocationUpdates(Function(Position) onLocationUpdate) async {
    // Simulate a single location update for testing
    onLocationUpdate(await getCurrentLocation());
  }

  @override
  double calculateDistance(Position newPosition) {
    return 0.1; // Return mock distance of 100 meters
  }

  @override
  void dispose() {
    // Cleanup not needed in test implementation
  }
}

// Custom test implementation of TripService for testing
class TestTripService extends TripService {
  List<Trip> mockTrips = [];

  TestTripService(AuthService authService, LocationService locationService)
      : super(authService, locationService);

  @override
  List<Trip> get recentTrips => mockTrips;

  void setMockTrips(List<Trip> trips) {
    mockTrips = trips;
    notifyListeners();
  }
}

void main() {
  late TestAuthService authService;
  late TestTripService tripService;
  late TestLocationService locationService;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    // Initialize test services before each test
    authService = TestAuthService();
    locationService = TestLocationService();
    fakeFirestore = FakeFirebaseFirestore();
    tripService = TestTripService(authService, locationService);
  });

  // Helper function to create a testable widget with all required providers
  Widget createTestableWidget() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: authService),
          ChangeNotifierProvider<TripService>.value(value: tripService),
          Provider<LocationService>.value(value: locationService),
        ],
        child: const DriveTrackerApp(),
      ),
    );
  }

  group('Start Page Tests', () {
    testWidgets('Shows login and signup buttons', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // Verify both authentication buttons are present
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('Navigates to login page correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // Tap login button and wait for navigation
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // Verify we're on the login page
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });
  });

  group('Authentication Flow Tests', () {
    testWidgets('Login flow works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // Navigate to login page
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // Enter login credentials
      await tester.enterText(
          find.byType(TextFormField).first,
          'test@example.com'
      );
      await tester.enterText(
          find.byType(TextFormField).last,
          'password123'
      );

      // Submit login form
      await tester.tap(find.text('Login').last);
      await tester.pumpAndSettle();

      // Verify successful login navigation
      expect(find.text('Start Trip'), findsOneWidget);
    });
  });

  group('Dashboard Tests', () {
    testWidgets('Shows empty state when no trips exist',
            (WidgetTester tester) async {
          // Set up authenticated state with no trips
          await authService.signIn(
              email: 'test@example.com',
              password: 'password123'
          );
          tripService.setMockTrips([]);

          await tester.pumpWidget(createTestableWidget());
          await tester.pumpAndSettle();

          // Verify empty state message is shown
          expect(find.text('No trips recorded yet'), findsOneWidget);
        });

    testWidgets('Shows start trip button when authenticated',
            (WidgetTester tester) async {
          // Set up authenticated state
          await authService.signIn(
              email: 'test@example.com',
              password: 'password123'
          );

          await tester.pumpWidget(createTestableWidget());
          await tester.pumpAndSettle();

          // Verify start trip button is present
          expect(find.text('Start Trip'), findsOneWidget);
          expect(find.byIcon(Icons.add), findsOneWidget);
        });
  });
}