import 'package:flutter/services.dart';

/// Sistem küçük penceresi. macOS'ta yüzen panel, Android'de etkinlik, iOS'ta sistem penceresi.
class OutsideWindow {
  static const _channel = MethodChannel('mias/outside');

  static Future<String> enter(String url) async {
    try {
      final mode = await _channel.invokeMethod<String>('enter', {'url': url});
      return mode ?? 'none';
    } on MissingPluginException {
      return 'none';
    } catch (_) {
      return 'none';
    }
  }

  static Future<void> bars(bool hide) async {
    try {
      await _channel.invokeMethod<void>('bars', {'hide': hide});
    } catch (_) {}
  }

  static void watchLeave(void Function()? onLeave) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'left') {
        onLeave?.call();
      }
    });
  }

  static Future<void> cursor(bool hide) async {
    try {
      await _channel.invokeMethod<void>('cursor', {'hide': hide});
    } catch (_) {}
  }

  static Future<bool> full() async {
    try {
      final on = await _channel.invokeMethod<bool>('full');
      return on ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> exit() async {
    try {
      await _channel.invokeMethod<void>('exit');
    } catch (_) {}
  }
}
