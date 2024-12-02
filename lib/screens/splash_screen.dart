import 'package:flutter/material.dart';
import '../../services/app_initializer.dart';

class SplashScreen extends StatelessWidget {
  final bool isInitializing;
  final InitializationStep initializationStep;

  const SplashScreen({
    Key? key,
    required this.isInitializing,
    required this.initializationStep,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.car_crash, // Or your app logo
                  size: 64,
                  color: Colors.blue,
                ),
                const SizedBox(height: 32),
                Text(
                  'Drive Tracker',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 48),
                if (isInitializing) ...[
                  LinearProgressIndicator(
                    value: initializationStep.progress,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    initializationStep.message,
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}