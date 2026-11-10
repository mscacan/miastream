/// Tarayıcıda dosya yok; küçük kayıtlar localStorage'da durur.
/// Yerel platformlarda hiçbir şey yapmaz.
library;

export 'web_disk_stub.dart' if (dart.library.js_interop) 'web_disk_web.dart';
