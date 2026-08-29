import 'package:flutter/services.dart';

class SafService {
  static const MethodChannel _channel = MethodChannel('com.onerdna.saturn/saf');

  static Future<String?> openDocumentTree() async {
    try {
      final String? uri = await _channel.invokeMethod('openDocumentTree');
      return uri;
    } on PlatformException catch (_) {
      return null;
    }
  }
}
