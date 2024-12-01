import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:drive_tracker/models/user_data.dart';
import 'package:drive_tracker/SQLite Database Helper.dart';

class AuthService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  UserData? _currentUser;

  UserData? get currentUser => _currentUser;

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Check if user already exists
      final existingUser = await _db.getUserByEmail(email, password);
      if (existingUser != null) {
        throw Exception('Email already registered');
      }

      // Create new user
      final user = UserData(
        uid: const Uuid().v4(),
        fullName: fullName.trim(),
        email: email.trim(),
        joinDate: DateTime.now(),
      );

      await _db.insertUser(user, password);
      _currentUser = user;
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to create account: $e');
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _db.getUserByEmail(email.trim(), password);
      if (user == null) {
        throw Exception('Invalid email or password');
      }

      _currentUser = user;
      notifyListeners();
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<void> signOut() async {
    _currentUser = null;
    notifyListeners();
  }
}