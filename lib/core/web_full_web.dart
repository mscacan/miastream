import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool?> toggleWebFull() async {
  final doc = web.document;
  try {
    if (doc.fullscreenElement != null) {
      await doc.exitFullscreen().toDart;
      return false;
    }
    await doc.documentElement?.requestFullscreen().toDart;
    return doc.fullscreenElement != null;
  } catch (_) {
    return doc.fullscreenElement != null;
  }
}

void watchWebFull(void Function(bool on)? onChange) {
  web.document.onfullscreenchange = onChange == null
      ? null
      : ((web.Event _) => onChange(web.document.fullscreenElement != null)).toJS;
}
