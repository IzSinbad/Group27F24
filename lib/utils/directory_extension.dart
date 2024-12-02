// lib/utils/directory_extension.dart
import 'dart:io';
import 'package:path/path.dart' as path;

extension DirectoryExtension on Directory {
  Future<File> childFile(String filename) async {
    return File(path.join(this.path, filename));
  }
}