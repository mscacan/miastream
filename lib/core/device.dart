import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Cihaz türü. Uygulama açılırken bir kez okunur.
abstract final class MiaDevice {
  static const _channel = MethodChannel('mias/outside');

  /// Kumandayla kullanılan büyük ekran: Android TV, Google TV, Fire TV.
  /// Tarayıcıda adrese ?tv=1 eklenirse TV düzeni denenir.
  static bool isTv = false;

  static Future<void> detect() async {
    if (kIsWeb) {
      isTv = Uri.base.queryParameters['tv'] == '1';
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      isTv = await _channel.invokeMethod<bool>('isTv').timeout(const Duration(seconds: 2)) ?? false;
    } catch (_) {
      isTv = false;
    }
  }
}
