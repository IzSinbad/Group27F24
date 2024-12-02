import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer' as dev;
import '../../services/auth_service.dart';
import 'package:drive_tracker/components/error_display.dart';
import 'package:drive_tracker/components/error_view.dart';
class LoadingScreen extends StatefulWidget {
  final Future<void> Function() loadData;
  final int timeoutSeconds;
  final Widget onSuccess;

  const LoadingScreen({
    Key? key,
    required this.loadData,
    this.timeoutSeconds = 30,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  bool _isLoading = true;
  String _currentStep = 'Initializing...';
  String? _error;
  Timer? _timeoutTimer;
  int _retryCount = 0;
  static const int maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  void _startLoading() {
    if (_retryCount >= maxRetries) {
      setState(() {
        _error = 'Maximum retry attempts reached. Please restart the app.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _currentStep = 'Loading user data...';
    });

    // Start timeout timer
    _timeoutTimer = Timer(Duration(seconds: widget.timeoutSeconds), () {
      if (mounted) {
        setState(() {
          _error = 'Loading timed out. Please check your connection and try again.';
          _isLoading = false;
        });
      }
    });

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      dev.log('Starting data load attempt ${_retryCount + 1}', name: 'LoadingScreen');

      await widget.loadData();

      if (mounted) {
        _timeoutTimer?.cancel();
        if (!mounted) return;

        // Navigate to success screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => widget.onSuccess),
        );
      }
    } catch (e, stack) {
      dev.log(
        'Data loading failed',
        error: e,
        stackTrace: stack,
        name: 'LoadingScreen',
      );

      if (mounted) {
        setState(() {
          _error = 'Failed to load data: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _retry() {
    _timeoutTimer?.cancel();
    _retryCount++;
    _startLoading();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: _error != null
                ? ErrorView(
              error: _error!,
              onRetry: _retryCount < maxRetries ? _retry : null,
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  _currentStep,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}