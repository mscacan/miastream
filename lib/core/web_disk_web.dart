import 'package:web/web.dart' as web;

abstract final class WebDisk {
  static String? read(String name) {
    try {
      return web.window.localStorage.getItem('mia.$name');
    } catch (_) {
      return null;
    }
  }

  /// Kota dolarsa sessizce vazgeçer; katalog yeniden indirilir.
  static void write(String name, String body) {
    try {
      web.window.localStorage.setItem('mia.$name', body);
    } catch (_) {
      try {
        web.window.localStorage.removeItem('mia.$name');
      } catch (_) {}
    }
  }
}
