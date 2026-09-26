import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../playback/media_entry.dart';
import '../playback/source_loader.dart';
import '../shell/shell_section.dart';
import 'user_source.dart';

/// Kütüphane boş başlar. Kaynak kullanıcı ekler.
const sourceRefreshDaily = 'daily';
const sourceRefreshWeekly = 'weekly';
const sourceRefreshMonthly = 'monthly';

const sourceRefreshLabels = {
  sourceRefreshDaily: 'Günlük',
  sourceRefreshWeekly: 'Haftalık',
  sourceRefreshMonthly: 'Aylık',
};

class UserLibrary extends ChangeNotifier {
  UserLibrary({SourceLoader? loader, Future<Directory> Function()? folder, DateTime Function()? now})
    : _loader = loader ?? const SourceLoader(),
      _folder = folder ?? getApplicationSupportDirectory,
      _now = now ?? DateTime.now;

  final SourceLoader _loader;
  final Future<Directory> Function() _folder;
  final DateTime Function() _now;
  final List<UserSource> _items = [];
  final Map<String, List<MediaEntry>> _entries = {};
  final Map<String, String> _errors = {};
  final Set<String> _loading = {};
  final Set<String> _favorites = {};
  String loadLabel = 'Bağlanıyor';
  int loadCount = 0;
  String _refresh = sourceRefreshWeekly;
  DateTime? _savedAt;
  Future<void>? _reloadJob;
  var _restored = false;
  var _disposed = false;

  SourceLoader get loader => _loader;

  List<UserSource> get items => List.unmodifiable(_items);

  bool get isLoading => _loading.isNotEmpty;

  String get refreshEvery => _refresh;

  String? get savedLabel {
    final at = _savedAt?.toLocal();
    if (at == null) {
      return null;
    }
    final day = at.day.toString().padLeft(2, '0');
    final month = at.month.toString().padLeft(2, '0');
    final hour = at.hour.toString().padLeft(2, '0');
    final minute = at.minute.toString().padLeft(2, '0');
    return '$day.$month.${at.year} $hour:$minute';
  }

  Future<void> get settled => _reloadJob ?? Future<void>.value();

  List<String> get messages => List.unmodifiable(_errors.values);

  List<MediaEntry> get entries => [for (final list in _entries.values) ...list];

  List<MediaEntry> entriesFor(ShellSection section) {
    return [
      for (final list in _entries.values)
        for (final entry in list)
          if (entry.section == section) entry,
    ];
  }

  bool isFavorite(String id) => _favorites.contains(id);

  int get favoriteCount => _favorites.length;

  List<MediaEntry> favoritesIn(ShellSection section) {
    return [
      for (final entry in entriesFor(section))
        if (_favorites.contains(entry.id)) entry,
    ];
  }

  void toggleFavorite(String id) {
    if (!_favorites.add(id)) {
      _favorites.remove(id);
    }
    _notify();
  }

  List<Map<String, String>> sourceBag() {
    return [
      for (final item in _items)
        {
          'id': item.id,
          'label': item.label,
          'kind': item.kind.name,
          'value': item.value,
          'username': item.username,
          'password': item.password,
          'mac': item.mac,
        },
    ];
  }

  Future<void> takeSources(List<UserSource> sources) async {
    for (final source in sources) {
      final exists = _items.any(
        (item) =>
            item.id == source.id ||
            (item.kind == source.kind &&
                item.value == source.value &&
                item.username == source.username &&
                item.mac == source.mac),
      );
      if (exists || !source.isComplete || source.id.trim().isEmpty) {
        continue;
      }
      await tryAdd(source);
    }
  }

  UserSource? sourceById(String id) {
    for (final source in _items) {
      if (source.id == id) {
        return source;
      }
    }
    return null;
  }

  Future<void> restore() async {
    if (_restored || _disposed) {
      return;
    }
    _restored = true;
    await _read();
    if (_disposed || _items.isEmpty) {
      return;
    }
    _notify();
    if (_shouldRefresh) {
      _reloadJob = _reloadSaved();
    }
  }

  Future<void> setRefreshEvery(String value) async {
    if (!sourceRefreshLabels.containsKey(value) || value == _refresh) {
      return;
    }
    _refresh = value;
    _notify();
    await _persist(catalog: false);
  }

  Future<void> refreshNow() {
    final job = _reloadSaved();
    _reloadJob = job;
    return job;
  }

  bool get _shouldRefresh {
    if (_items.isEmpty) {
      return false;
    }
    if (_items.any((item) => !_entries.containsKey(item.id))) {
      return true;
    }
    final at = _savedAt;
    if (at == null) {
      return true;
    }
    return _now().difference(at) >= _refreshSpan;
  }

  Duration get _refreshSpan {
    return switch (_refresh) {
      sourceRefreshDaily => const Duration(days: 1),
      sourceRefreshMonthly => const Duration(days: 30),
      _ => const Duration(days: 7),
    };
  }

  Future<void> _reloadSaved() async {
    var changed = false;
    for (final source in List<UserSource>.of(_items)) {
      if (await _reload(source)) {
        changed = true;
      }
    }
    if (!changed || _disposed) {
      return;
    }
    _savedAt = _now();
    await _persist();
  }

  Future<void> drop(String id) async {
    _items.removeWhere((item) => item.id == id);
    _entries.remove(id);
    _errors.remove(id);
    _notify();
    await _persist();
  }

  Future<String?> tryAdd(UserSource source) async {
    if (!source.isComplete) {
      return 'Eksik alan var.';
    }
    final stored = _stored(source);
    if (_items.every((item) => item.id != stored.id)) {
      _items.add(stored);
    }
    await _persist(catalog: false);
    _loading.add(stored.id);
    loadLabel = 'Bağlanıyor';
    loadCount = 0;
    _notify();
    try {
      final entries = await _loader.load(stored, onPulse: _pulse);
      if (_disposed) {
        return 'Kaynak yanıt vermedi';
      }
      _entries[stored.id] = entries;
      _errors.remove(stored.id);
      _savedAt = _now();
      await _persist();
      return null;
    } on SourceLoadException catch (error) {
      _errors[stored.id] = error.message;
      return error.message;
    } catch (_) {
      _errors[stored.id] = 'Kaynak yanıt vermedi';
      return 'Kaynak yanıt vermedi';
    } finally {
      _loading.remove(stored.id);
      if (!_disposed) {
        _notify();
      }
    }
  }

  Future<bool> _reload(UserSource source) async {
    _loading.add(source.id);
    _notify();
    try {
      final entries = await _loader.load(source, onPulse: _pulse);
      if (_disposed) {
        return false;
      }
      _entries[source.id] = entries;
      _errors.remove(source.id);
      return true;
    } on SourceLoadException catch (error) {
      _errors[source.id] = error.message;
      return false;
    } catch (_) {
      _errors[source.id] = 'Kaynak yanıt vermedi';
      return false;
    } finally {
      _loading.remove(source.id);
      if (!_disposed) {
        _notify();
      }
    }
  }

  Future<void> _read() async {
    try {
      final dir = await _directory();
      final file = File('${dir.path}/kaynaklar.json');
      if (!file.existsSync()) {
        return;
      }
      final decoded = jsonDecode(await file.readAsString());
      final rows = decoded is List
          ? decoded
          : decoded is Map
          ? decoded['sources']
          : null;
      if (decoded is Map) {
        final refresh = decoded['refresh']?.toString();
        if (sourceRefreshLabels.containsKey(refresh)) {
          _refresh = refresh!;
        }
        final savedAt = decoded['savedAt']?.toString();
        if (savedAt != null) {
          _savedAt = DateTime.tryParse(savedAt);
        }
      }
      if (rows is List) {
        for (final item in rows) {
          if (item is! Map) {
            continue;
          }
          final source = _sourceFrom(item);
          if (source != null && _items.every((have) => have.id != source.id)) {
            _items.add(source);
          }
        }
      }
      final catalog = File('${dir.path}/katalog.json');
      if (!catalog.existsSync()) {
        return;
      }
      final listed = jsonDecode(await catalog.readAsString());
      if (listed is! List) {
        return;
      }
      for (final item in listed) {
        if (item is! Map) {
          continue;
        }
        final entry = mediaEntryFrom(item);
        if (entry == null || _items.every((source) => source.id != entry.sourceId)) {
          continue;
        }
        _entries.putIfAbsent(entry.sourceId, () => []).add(entry);
      }
    } catch (_) {}
  }

  Future<void> _persist({bool catalog = true}) async {
    try {
      final dir = await _directory();
      await _writeAtomic(
        dir,
        'kaynaklar.json',
        jsonEncode({
          'refresh': _refresh,
          'savedAt': _savedAt?.toUtc().toIso8601String(),
          'sources': sourceBag(),
        }),
      );
      if (!catalog) {
        return;
      }
      await _writeAtomic(
        dir,
        'katalog.json',
        jsonEncode([
          for (final list in _entries.values)
            for (final entry in list) entry.toJson(),
        ]),
      );
    } catch (_) {}
  }

  Future<Directory> _directory() async {
    final pending = _folder();
    final dir = Platform.environment.containsKey('FLUTTER_TEST')
        ? await pending.timeout(const Duration(seconds: 2))
        : await pending;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _writeAtomic(Directory dir, String name, String body) async {
    final file = File('${dir.path}/$name');
    final tmp = File('${dir.path}/$name.tmp');
    await tmp.writeAsString(body, flush: true);
    await tmp.rename(file.path);
  }

  void _pulse(String label, int count) {
    loadLabel = label;
    loadCount = count;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

UserSource _stored(UserSource source) {
  return UserSource(
    id: source.id,
    label: source.label.trim(),
    kind: source.kind,
    value: source.value.trim(),
    username: source.username.trim(),
    password: source.password,
    mac: source.mac.trim(),
  );
}

UserSource? _sourceFrom(Map item) {
  final kindName = item['kind']?.toString();
  final kind = UserSourceKind.values.where((value) => value.name == kindName).firstOrNull;
  if (kind == null) {
    return null;
  }
  final source = UserSource(
    id: item['id']?.toString() ?? '',
    label: item['label']?.toString() ?? '',
    kind: kind,
    value: item['value']?.toString() ?? '',
    username: item['username']?.toString() ?? '',
    password: item['password']?.toString() ?? '',
    mac: item['mac']?.toString() ?? '',
  );
  if (!source.isComplete || source.id.trim().isEmpty) {
    return null;
  }
  return source;
}
