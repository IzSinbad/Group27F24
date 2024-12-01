import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/trip.dart';

class StorageService {
  // Base paths for storing trip-related files
  static const String _tripsPath = 'trips';
  static const String _reportsPath = 'reports';
  static const String _imagesPath = 'images';

  // Get the base directory for app storage
  Future<Directory> get _baseDir async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory(path.join(appDir.path, 'drive_tracker'));
  }

  // Ensure directories exist
  Future<void> _ensureDirectoryExists(String dirPath) async {
    final directory = Directory(dirPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  // Get trip directory path
  Future<String> _getTripDirectory(String userId, String tripId) async {
    final base = await _baseDir;
    return path.join(base.path, _tripsPath, userId, tripId);
  }

  // Upload a PDF report for a specific trip
  Future<String> saveTripReport(String userId, String tripId, File report) async {
    try {
      final tripDir = await _getTripDirectory(userId, tripId);
      final reportsDir = path.join(tripDir, _reportsPath);
      await _ensureDirectoryExists(reportsDir);

      final fileName = 'trip_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = path.join(reportsDir, fileName);

      // Copy the report to our storage location
      await report.copy(filePath);

      // Return the relative path for database storage
      return path.relative(filePath, from: (await _baseDir).path);
    } catch (e) {
      throw Exception('Failed to save trip report: $e');
    }
  }

  // Delete a trip report
  Future<void> deleteTripReport(String userId, String tripId, String fileName) async {
    try {
      final tripDir = await _getTripDirectory(userId, tripId);
      final filePath = path.join(tripDir, _reportsPath, fileName);

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete trip report: $e');
    }
  }

  // Save trip-related images
  Future<String> saveTripImage(String userId, String tripId, File image) async {
    try {
      final tripDir = await _getTripDirectory(userId, tripId);
      final imagesDir = path.join(tripDir, _imagesPath);
      await _ensureDirectoryExists(imagesDir);

      final extension = path.extension(image.path);
      final fileName = 'trip_image_${DateTime.now().millisecondsSinceEpoch}$extension';
      final filePath = path.join(imagesDir, fileName);

      // Copy the image to our storage location
      await image.copy(filePath);

      // Return the relative path for database storage
      return path.relative(filePath, from: (await _baseDir).path);
    } catch (e) {
      throw Exception('Failed to save trip image: $e');
    }
  }

  // Get all reports for a specific trip
  Future<List<File>> getTripReports(String userId, String tripId) async {
    try {
      final tripDir = await _getTripDirectory(userId, tripId);
      final reportsDir = path.join(tripDir, _reportsPath);

      if (!await Directory(reportsDir).exists()) {
        return [];
      }

      final files = await Directory(reportsDir)
          .list()
          .where((entity) => entity is File)
          .map((entity) => entity as File)
          .toList();

      return files;
    } catch (e) {
      throw Exception('Failed to get trip reports: $e');
    }
  }

  // Clean up all files associated with a trip
  Future<void> cleanupTripFiles(String userId, String tripId) async {
    try {
      final tripDir = await _getTripDirectory(userId, tripId);
      final directory = Directory(tripDir);

      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (e) {
      throw Exception('Failed to cleanup trip files: $e');
    }
  }

  // Get file from relative path
  Future<File> getFile(String relativePath) async {
    final base = await _baseDir;
    return File(path.join(base.path, relativePath));
  }
}