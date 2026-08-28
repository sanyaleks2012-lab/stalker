import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SafService {
  /// Возвращает корневую директорию context.filesDir, 
  /// доступную через AppDocumentsProvider
  static Future<Directory> getAppFilesDir() async {
    return await getApplicationDocumentsDirectory();
  }

  /// Пример создания файла, который сразу станет виден в SAF
  static Future<File> createFile(String fileName, String content) async {
    final dir = await getAppFilesDir();
    final file = File('${dir.path}/$fileName');
    return await file.writeAsString(content);
  }
}
