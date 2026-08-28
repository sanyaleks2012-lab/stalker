import 'package:flutter/services.dart';

class BridgeApi {
  static const _channel = MethodChannel('com.onerdna.saturn/shizuku');

  static Future<bool?> pingBinder() async {
    return await _channel.invokeMethod("pingBinder");
  }

  static Future<void> requestPermission(int requestCode) async {
    await _channel.invokeMethod("requestPermission", {
      "requestCode": requestCode,
    });
  }

  static Future<bool?> checkPermission() async {
    return await _channel.invokeMethod("checkPermission");
  }

  static Future<String?> runCommand(String command) async {
    return await _channel.invokeMethod("runCommand", {"command": command});
  }

  static Future<bool> isBinderServiceAvailable() async {
    return await _channel.invokeMethod("isBinderServiceAvailable");
  }

  static Future<String> startBinderService() async {
    return await _channel.invokeMethod("startBinderService");
  }
}
