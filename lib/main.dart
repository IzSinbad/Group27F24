import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:developer' as dev;
import 'services/auth_service.dart';
import 'screens/start_page.dart';
import 'package:drive_tracker/components/error_display.dart';
import'package:drive_tracker/screens/error_screen.dart';
void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final authService = AuthService();

    try {
      // Initialize auth service before running app
      await authService.initialize();

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(
              value: authService,
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

      // Show error screen if initialization fails
      runApp(
        MaterialApp(
          home: ErrorScreen(
            error: 'Failed to initialize app: $e',
            onRetry: () async {
              // Retry initialization
              await authService.initialize();
              main();
            },
          ),
        ),
      );
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
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (auth.error != null) {
            return ErrorScreen(
              error: auth.error!,
              onRetry: () => auth.initialize(),
            );
          }

          return const StartPage();
        },
      ),
    );
  }
}