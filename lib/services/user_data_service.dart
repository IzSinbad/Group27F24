import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import '../models/user_data.dart';

class UserDataService extends ChangeNotifier {
  final SharedPreferences _prefs;
  final Duration timeoutDuration;

  UserData? _userData;
  bool _isLoading = false;
  String? _error;
  Timer? _timeoutTimer;

  UserDataService(this._prefs, {
    this.timeoutDuration = const Duration(seconds: 30),
  });

  // Getters
  UserData? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUserData(String userId) async {
    if (_isLoading) return;

    try {
      _setLoading(true);
      dev.log('Starting user data load for ID: $userId', name: 'UserDataService');

      // Start timeout timer
      _timeoutTimer = Timer(timeoutDuration, () {
        _handleError('Data loading timed out');
      });

      // Attempt to load from local storage first
      final cachedData = await _loadFromCache(userId);
      if (cachedData != null) {
        _userData = cachedData;
        _setLoading(false);
        notifyListeners();
      }

      // Load from remote (assuming you have a remote data source)
      final remoteData = await _loadFromRemote(userId);
      if (remoteData != null) {
        _userData = remoteData;
        await _saveToCache(userId, remoteData);
      }

      _timeoutTimer?.cancel();
      dev.log('User data loaded successfully', name: 'UserDataService');

    } catch (e, stack) {
      dev.log(
        'Failed to load user data',
        error: e,
        stackTrace: stack,
        name: 'UserDataService',
      );
      _handleError('Failed to load user data: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<UserData?> _loadFromCache(String userId) async {
    try {
      final jsonData = _prefs.getString('user_data_$userId');
      if (jsonData != null) {
        return UserData.fromMap(jsonDecode(jsonData));
      }
    } catch (e) {
      dev.log('Cache read error: $e', name: 'UserDataService');
    }
    return null;
  }

  Future<UserData?> _loadFromRemote(String userId) async {
    // Implement your remote data loading logic here
    // This is a placeholder implementation
    await Future.delayed(const Duration(seconds: 2));
    return null;
  }

  Future<void> _saveToCache(String userId, UserData data) async {
    try {
      await _prefs.setString(
        'user_data_$userId',
        jsonEncode(data.toMap()),
      );
    } catch (e) {
      dev.log('Cache write error: $e', name: 'UserDataService');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    if (!loading) {
      _timeoutTimer?.cancel();
    }
    notifyListeners();
  }

  void _handleError(String message) {
    _error = message;
    _setLoading(false);
    dev.log('Error: $message', name: 'UserDataService');
  }

  Future<void> clearUserData() async {
    try {
      _userData = null;
      await _prefs.remove('user_data_${_userData?.uid}');
      notifyListeners();
    } catch (e) {
      dev.log('Error clearing user data: $e', name: 'UserDataService');
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }
}

class UserDataException implements Exception {
  final String message;

  UserDataException(this.message);

  @override
  String toString() => message;
}