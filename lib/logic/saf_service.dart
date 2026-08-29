import 'dart:io';

class SafService {
  static Future<void> init() async {
    final Directory internalDir = Directory('/data/data/com.onerdna.saturn/files');
    if (!await internalDir.exists()) {
      await internalDir.create(recursive: true);
    }
  }
}
