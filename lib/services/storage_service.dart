import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;

  StorageService._internal();

  SharedPreferences? _prefs;
  Directory? _localDir;
  bool _usePrefs = true;

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _usePrefs = true;
    } catch (e) {
      dev.log('SharedPreferences failed, using file storage', name: 'StorageService');
      _usePrefs = false;
      _localDir = await getApplicationDocumentsDirectory();
    }
  }

  Future<void> setString(String key, String value) async {
    if (_usePrefs && _prefs != null) {
      await _prefs!.setString(key, value);
    } else {
      await _writeFile(key, value);
    }
  }

  Future<String?> getString(String key) async {
    if (_usePrefs && _prefs != null) {
      return _prefs!.getString(key);
    } else {
      return await _readFile(key);
    }
  }

  Future<void> remove(String key) async {
    if (_usePrefs && _prefs != null) {
      await _prefs!.remove(key);
    } else {
      await _deleteFile(key);
    }
  }

  Future<void> clear() async {
    if (_usePrefs && _prefs != null) {
      await _prefs!.clear();
    } else {
      await _clearFiles();
    }
  }

  // File system fallback methods
  Future<void> _writeFile(String key, String value) async {
    try {
      final file = File('${_localDir!.path}/$key.dat');
      await file.writeAsString(base64Encode(utf8.encode(value)));
    } catch (e) {
      dev.log('Error writing file: $e', name: 'StorageService');
      rethrow;
    }
  }

  Future<String?> _readFile(String key) async {
    try {
      final file = File('${_localDir!.path}/$key.dat');
      if (!await file.exists()) return null;
      final contents = await file.readAsString();
      return utf8.decode(base64Decode(contents));
    } catch (e) {
      dev.log('Error reading file: $e', name: 'StorageService');
      return null;
    }
  }

  Future<void> _deleteFile(String key) async {
    try {
      final file = File('${_localDir!.path}/$key.dat');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      dev.log('Error deleting file: $e', name: 'StorageService');
    }
  }

  Future<void> _clearFiles() async {
    try {
      final dir = Directory(_localDir!.path);
      await for (final file in dir.list()) {
        if (file is File && file.path.endsWith('.dat')) {
          await file.delete();
        }
      }
    } catch (e) {
      dev.log('Error clearing files: $e', name: 'StorageService');
    }
  }
}