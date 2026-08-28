import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:saturn/main.dart';

class SafService {
  static late final Directory rootDir;

  static Future<void> init() async {
    rootDir = await getApplicationDocumentsDirectory();
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
    }
    logger.i("SAF Directory initialized: ${rootDir.path}");
  }

  static File getFile(String relativePath) {
    return File('${rootDir.path}/$relativePath');
  }

  static Directory getDirectory(String relativePath) {
    return Directory('${rootDir.path}/$relativePath');
  }
}
