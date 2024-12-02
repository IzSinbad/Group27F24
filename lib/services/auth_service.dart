import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:developer' as dev;
import '../models/user_data.dart';

class AuthService extends ChangeNotifier {
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  UserData? _currentUser;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  UserData? get currentUser => _currentUser;

  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      dev.log('Initializing AuthService...', name: 'AuthService');
      _setLoading(true);

      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;

      // Try to restore session
      await _restoreSession();

      dev.log('AuthService initialized successfully', name: 'AuthService');
    } catch (e, stack) {
      dev.log(
        'Failed to initialize AuthService',
        error: e,
        stackTrace: stack,
        name: 'AuthService',
      );
      _error = 'Initialization failed: $e';
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      _validateInitialization();
      _setLoading(true);
      _error = null;

      // Validate input
      _validateSignUpData(email, password, fullName);

      // Check if email exists
      final existingUser = await _getUserByEmail(email);
      if (existingUser != null) {
        throw AuthException('Email already registered');
      }

      // Create new user
      final userData = UserData(
        uid: const Uuid().v4(),
        email: email,
        fullName: fullName,
        joinDate: DateTime.now(),
      );

      // Save user data
      await _saveUserData(userData, password);

      _currentUser = userData;
      notifyListeners();

      dev.log('User signed up successfully', name: 'AuthService');
    } catch (e, stack) {
      dev.log(
        'Sign up failed',
        error: e,
        stackTrace: stack,
        name: 'AuthService',
      );
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _validateInitialization();
      _setLoading(true);
      _error = null;

      final userData = await _getUserByEmail(email);
      if (userData == null) {
        throw AuthException('User not found');
      }

      final storedPassword = _prefs!.getString('password_${userData.uid}');
      if (storedPassword != _hashPassword(password)) {
        throw AuthException('Invalid password');
      }

      _currentUser = userData;
      await _saveSession(userData);

      dev.log('User signed in successfully', name: 'AuthService');
    } catch (e, stack) {
      dev.log(
        'Sign in failed',
        error: e,
        stackTrace: stack,
        name: 'AuthService',
      );
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }
  // Add this method to your AuthService class
  Future<void> signOut() async {
    try {
      _validateInitialization();
      _setLoading(true);
      _error = null;

      // Clear current session
      await _prefs!.remove('current_user');

      // Clear current user data
      _currentUser = null;

      dev.log('User signed out successfully', name: 'AuthService');
    } catch (e, stack) {
      dev.log(
        'Sign out failed',
        error: e,
        stackTrace: stack,
        name: 'AuthService',
      );
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Private helper methods
  void _validateInitialization() {
    if (!_isInitialized || _prefs == null) {
      throw AuthException('AuthService not initialized');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> _saveUserData(UserData userData, String password) async {
    await Future.wait([
      _prefs!.setString('user_${userData.uid}', jsonEncode(userData.toMap())),
      _prefs!.setString('password_${userData.uid}', _hashPassword(password)),
      _prefs!.setString('email_${userData.email}', userData.uid),
    ]);
  }

  Future<void> _saveSession(UserData userData) async {
    await _prefs!.setString('current_user', userData.uid);
  }

  Future<void> _restoreSession() async {
    final userId = _prefs!.getString('current_user');
    if (userId != null) {
      final userJson = _prefs!.getString('user_$userId');
      if (userJson != null) {
        _currentUser = UserData.fromMap(jsonDecode(userJson));
      }
    }
  }

  Future<UserData?> _getUserByEmail(String email) async {
    final userId = _prefs!.getString('email_$email');
    if (userId == null) return null;

    final userJson = _prefs!.getString('user_$userId');
    if (userJson == null) return null;

    return UserData.fromMap(jsonDecode(userJson));
  }

  String _hashPassword(String password) {
    // Implement proper password hashing
    return password; // Simplified for example
  }

  void _validateSignUpData(String email, String password, String fullName) {
    if (email.isEmpty || !email.contains('@')) {
      throw AuthException('Invalid email address');
    }
    if (password.length < 6) {
      throw AuthException('Password must be at least 6 characters');
    }
    if (fullName.isEmpty) {
      throw AuthException('Full name is required');
    }
  }
}

class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}