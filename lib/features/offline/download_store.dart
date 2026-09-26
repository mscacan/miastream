import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class SavedCopy {
  const SavedCopy({
    required this.id,
    required this.title,
    required this.path,
    this.artwork,
  });

  final String id;
  final String title;
  final String path;
  final String? artwork;
}

/// İndirilen dosya uygulama klasöründe durur. Uzak adres kayda yazılmaz.
class DownloadStore extends ChangeNotifier {
  final List<SavedCopy> items = [];
  final Map<String, double> progress = {};
  final Map<String, String> pendingTitle = {};
  final Map<String, String> errors = {};
  Future<void>? _loading;
  DateTime _painted = DateTime.fromMillisecondsSinceEpoch(0);

  bool has(String id) => items.any((item) => item.id == id);

  double? fraction(String id) => progress[id];

  Future<void> ensureLoaded() {
    return _loading ??= _read();
  }

  Future<void> save({
    required String id,
    required String title,
    required String url,
    String? artwork,
  }) async {
    if (has(id) || progress.containsKey(id)) {
      return;
    }
    await ensureLoaded();
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      errors[id] = 'Adres okunamadı';
      notifyListeners();
      return;
    }
    progress[id] = 0;
    pendingTitle[id] = title;
    errors.remove(id);
    notifyListeners();
    final folder = await _folder();
    final file = File('${folder.path}/${_safe(id)}.${_extension(uri)}');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    IOSink? sink;
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 20));
      request.headers.set(HttpHeaders.userAgentHeader, 'MiaStream');
      final response = await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode >= 400) {
        throw const FileSystemException('Sunucu dosyayı vermedi');
      }
      final total = response.contentLength;
      var received = 0;
      sink = file.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          _paint(id, received / total);
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      items.insert(
        0,
        SavedCopy(id: id, title: title, path: file.path, artwork: artwork),
      );
      progress.remove(id);
      pendingTitle.remove(id);
      await _write(folder);
      notifyListeners();
    } catch (_) {
      await sink?.close();
      if (file.existsSync()) {
        await file.delete();
      }
      progress.remove(id);
      pendingTitle.remove(id);
      errors[id] = 'İndirme tamamlanamadı';
      notifyListeners();
    } finally {
      client.close(force: true);
    }
  }

  Future<void> remove(String id) async {
    await ensureLoaded();
    SavedCopy? found;
    for (final item in items) {
      if (item.id == id) {
        found = item;
      }
    }
    if (found == null) {
      return;
    }
    final file = File(found.path);
    if (file.existsSync()) {
      await file.delete();
    }
    items.removeWhere((item) => item.id == id);
    await _write(await _folder());
    notifyListeners();
  }

  void _paint(String id, double value) {
    progress[id] = value.clamp(0, 1);
    final now = DateTime.now();
    if (now.difference(_painted).inMilliseconds < 250 && value < 1) {
      return;
    }
    _painted = now;
    notifyListeners();
  }

  Future<void> _read() async {
    final folder = await _folder();
    final manifest = File('${folder.path}/kayitlar.json');
    if (!manifest.existsSync()) {
      return;
    }
    try {
      final decoded = jsonDecode(await manifest.readAsString());
      if (decoded is! List) {
        return;
      }
      for (final row in decoded) {
        if (row is! Map) {
          continue;
        }
        final id = row['id']?.toString() ?? '';
        final title = row['title']?.toString() ?? '';
        final name = row['file']?.toString() ?? '';
        if (id.isEmpty || title.isEmpty || name.isEmpty) {
          continue;
        }
        final file = File('${folder.path}/$name');
        if (!file.existsSync()) {
          continue;
        }
        items.add(
          SavedCopy(
            id: id,
            title: title,
            path: file.path,
            artwork: row['artwork']?.toString(),
          ),
        );
      }
    } catch (_) {
      items.clear();
    }
    notifyListeners();
  }

  Future<void> _write(Directory folder) async {
    final manifest = File('${folder.path}/kayitlar.json');
    final rows = [
      for (final item in items)
        {
          'id': item.id,
          'title': item.title,
          'file': item.path.split(Platform.pathSeparator).last,
          'artwork': ?item.artwork,
        },
    ];
    await manifest.writeAsString(jsonEncode(rows));
  }

  Future<Directory> _folder() async {
    final support = await getApplicationSupportDirectory();
    final folder = Directory('${support.path}/indirilenler');
    if (!folder.existsSync()) {
      await folder.create(recursive: true);
    }
    return folder;
  }
}

String _safe(String id) {
  final cleaned = id.replaceAll(RegExp(r'[^\w\-]+'), '_');
  return cleaned.isEmpty ? 'kayit' : cleaned;
}

String _extension(Uri uri) {
  final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) {
    return 'mkv';
  }
  final ext = name.substring(dot + 1).toLowerCase();
  if (ext.length > 4 || !RegExp(r'^[a-z0-9]+$').hasMatch(ext)) {
    return 'mkv';
  }
  return ext;
}
