import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'error_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        // Check loading state
        if (!auth.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Check for errors
        if (auth.error != null) {
          return ErrorScreen(
            error: auth.error!,
            onRetry: () async {
              try {
                await auth.initialize();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
          );
        }

        // Navigate based on auth state
        if (auth.currentUser != null) {
          return const DashboardPage();
        }

        return const LoginPage();
      },
    );
  }
}