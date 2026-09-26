import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../playback/media_entry.dart';

class UserShelf {
  const UserShelf(this.name, this.ids);

  final String name;
  final List<String> ids;
}

class KeptSpot {
  const KeptSpot({required this.title, required this.ms, this.frame, this.done = false});

  final String title;
  final int ms;
  final String? frame;
  final bool done;
}

/// Favoriler, raflar ve kaldığın yer. Tek kayıt.
class KeepStore extends ChangeNotifier {
  KeepStore();

  var _loaded = false;
  final Set<String> _favorites = {};
  final Map<String, KeptSpot> _spots = {};
  final Map<String, int> _intros = {};
  final List<_Shelf> _shelves = [];

  int get favoriteCount => _favorites.length;

  List<UserShelf> get shelves => [
    for (final shelf in _shelves) UserShelf(shelf.name, List.unmodifiable(shelf.ids)),
  ];

  bool isFavorite(String id) => _favorites.contains(id);

  List<MediaEntry> favoritesIn(List<MediaEntry> entries) {
    return [for (final entry in entries) if (_favorites.contains(entry.id)) entry];
  }

  KeptSpot? spotOf(String id) => _spots[id];

  int? introOf(String id) => _intros[id];

  List<MediaEntry> spotsIn(List<MediaEntry> entries) {
    return recentIn(entries);
  }

  List<MediaEntry> recentIn(List<MediaEntry> entries) {
    final byId = {for (final entry in entries) entry.id: entry};
    final recent = <MediaEntry>[];
    final seen = <String>{};
    for (final id in _spots.keys.toList().reversed) {
      if ((_spots[id]?.ms ?? 0) <= 8000) {
        continue;
      }
      final entry = byId[id] ?? _parentEntry(id, byId);
      if (entry != null && seen.add(entry.id)) {
        recent.add(entry);
      }
    }
    return recent;
  }

  Set<String> doneIds() {
    return {
      for (final item in _spots.entries)
        if (item.value.done && !item.key.contains('|')) item.key,
    };
  }

  List<OpenEpisode> unfinishedEpisodes(List<MediaEntry> entries) {
    final byId = {for (final entry in entries) entry.id: entry};
    final open = <OpenEpisode>[];
    for (final id in _spots.keys.toList().reversed) {
      final spot = _spots[id];
      if (spot == null || spot.done || spot.ms <= 8000) {
        continue;
      }
      final parts = id.split('|');
      if (parts.length < 3) {
        final entry = byId[id];
        if (entry != null) {
          open.add(OpenEpisode(entry: entry, title: spot.title, ms: spot.ms));
        }
        continue;
      }
      final entry = byId[parts.first];
      if (entry == null) {
        continue;
      }
      open.add(
        OpenEpisode(
          entry: entry,
          title: spot.title,
          ms: spot.ms,
          season: int.tryParse(parts[1]),
          number: int.tryParse(parts[2]),
        ),
      );
    }
    return open;
  }

  List<MediaEntry> framesIn(List<MediaEntry> entries) {
    return [
      for (final entry in entries)
        if (_spots[entry.id]?.frame != null) entry,
    ];
  }

  Map<String, dynamic> carryBag() {
    return {
      'favorites': _favorites.toList(),
      'spots': [
        for (final item in _spots.entries)
          {'id': item.key, 'title': item.value.title, 'ms': item.value.ms, 'done': item.value.done},
      ],
    };
  }

  void absorbBag(Map raw) {
    _readBag(raw, merge: true);
    notifyListeners();
    _save();
  }

  void toggleFavorite(String id) {
    if (!_favorites.add(id)) {
      _favorites.remove(id);
    }
    notifyListeners();
    _save();
  }

  void keepSpot(String id, {required String title, required int ms, bool done = false}) {
    final previous = _spots.remove(id);
    _spots[id] = KeptSpot(title: title, ms: ms, frame: previous?.frame, done: done);
    notifyListeners();
    _save();
  }

  Future<void> keepFrame(String id, {required String title, required Uint8List bytes}) async {
    try {
      final folder = await _frames();
      final file = File('${folder.path}/${_safe(id)}.jpg');
      await file.writeAsBytes(bytes, flush: true);
      final previous = _spots.remove(id);
      _spots[id] = KeptSpot(
        title: title,
        ms: previous?.ms ?? 0,
        frame: file.path,
        done: previous?.done ?? false,
      );
      notifyListeners();
      await _save();
    } catch (_) {}
  }

  void keepIntro(String id, int ms) {
    _intros[id] = ms;
    notifyListeners();
    _save();
  }

  void createShelf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    for (final shelf in _shelves) {
      if (shelf.name.toLowerCase() == trimmed.toLowerCase()) {
        return;
      }
    }
    _shelves.add(_Shelf(trimmed, []));
    notifyListeners();
    _save();
  }

  void addToShelf(String name, String id) {
    for (final shelf in _shelves) {
      if (shelf.name == name && !shelf.ids.contains(id)) {
        shelf.ids.add(id);
        notifyListeners();
        _save();
        return;
      }
    }
  }

  List<MediaEntry> shelfEntries(UserShelf shelf, List<MediaEntry> entries) {
    final ids = shelf.ids.toSet();
    return [for (final entry in entries) if (ids.contains(entry.id)) entry];
  }

  List<MediaEntry> shortOnes(List<MediaEntry> entries) {
    return [
      for (final entry in entries)
        if (entry.minutes != null && entry.minutes! > 0 && entry.minutes! <= 45) entry,
    ];
  }

  Future<void> ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    try {
      final support = await getApplicationSupportDirectory();
      final file = File('${support.path}/izleme.json');
      if (file.existsSync()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          _readBag(decoded, merge: false);
          notifyListeners();
        }
        return;
      }
      final previous = File('${support.path}/koltuk/koltuklar.json');
      if (!previous.existsSync()) {
        return;
      }
      final decoded = jsonDecode(await previous.readAsString());
      if (decoded is! Map) {
        return;
      }
      final bag = _earlierBag(decoded);
      if (bag != null) {
        _readBag(bag, merge: false);
        notifyListeners();
        await _save();
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final support = await getApplicationSupportDirectory();
      final file = File('${support.path}/izleme.json');
      await file.writeAsString(jsonEncode(_toJson()));
    } catch (_) {}
  }

  Map<String, dynamic> _toJson() {
    return {
      'favorites': _favorites.toList(),
      'intros': _intros,
      'shelves': [
        for (final shelf in _shelves) {'name': shelf.name, 'ids': shelf.ids},
      ],
      'spots': {
        for (final item in _spots.entries)
          item.key: {
            'title': item.value.title,
            'ms': item.value.ms,
            'frame': ?item.value.frame,
            if (item.value.done) 'done': true,
          },
      },
    };
  }

  void _readBag(Map raw, {required bool merge}) {
    if (!merge) {
      _favorites.clear();
      _spots.clear();
      _intros.clear();
      _shelves.clear();
    }
    final favorites = raw['favorites'];
    if (favorites is List) {
      _favorites.addAll(favorites.map((item) => '$item'));
    }
    final intros = raw['intros'];
    if (intros is Map) {
      for (final item in intros.entries) {
        final ms = int.tryParse('${item.value}');
        if (ms != null) {
          _intros['${item.key}'] = ms;
        }
      }
    }
    final shelves = raw['shelves'];
    if (shelves is List) {
      for (final item in shelves) {
        if (item is! Map) {
          continue;
        }
        final shelfName = item['name']?.toString().trim() ?? '';
        if (shelfName.isEmpty) {
          continue;
        }
        final ids = item['ids'];
        _shelves.add(_Shelf(shelfName, [if (ids is List) ...ids.map((id) => '$id')]));
      }
    }
    final spots = raw['spots'];
    if (spots is Map) {
      for (final item in spots.entries) {
        final value = item.value;
        if (value is! Map) {
          continue;
        }
        final id = '${item.key}';
        final previous = _spots.remove(id);
        _spots[id] = KeptSpot(
          title: value['title']?.toString() ?? previous?.title ?? '',
          ms: int.tryParse('${value['ms']}') ?? previous?.ms ?? 0,
          frame: value['frame']?.toString() ?? previous?.frame,
          done: value['done'] == true || previous?.done == true,
        );
      }
    }
    if (spots is List) {
      for (final item in spots) {
        if (item is! Map) {
          continue;
        }
        final id = item['id']?.toString() ?? '';
        if (id.isEmpty) {
          continue;
        }
        final previous = _spots.remove(id);
        _spots[id] = KeptSpot(
          title: item['title']?.toString() ?? previous?.title ?? '',
          ms: int.tryParse('${item['ms']}') ?? previous?.ms ?? 0,
          frame: previous?.frame,
          done: item['done'] == true || previous?.done == true,
        );
      }
    }
  }

  Future<Directory> _frames() async {
    final support = await getApplicationSupportDirectory();
    final folder = Directory('${support.path}/kareler');
    if (!folder.existsSync()) {
      await folder.create(recursive: true);
    }
    return folder;
  }
}

Map? _earlierBag(Map decoded) {
  final packed = decoded['seats'];
  if (packed is Map) {
    final active = decoded['active']?.toString();
    final current = active == null ? null : packed[active];
    if (current is Map) {
      return current;
    }
    for (final value in packed.values) {
      if (value is Map) {
        return value;
      }
    }
  }
  if (decoded['favorites'] != null || decoded['spots'] != null) {
    return decoded;
  }
  return null;
}

class _Shelf {
  _Shelf(this.name, this.ids);

  final String name;
  final List<String> ids;
}

String _safe(String id) => id.replaceAll(RegExp(r'[^\w\-]+'), '_');

MediaEntry? _parentEntry(String id, Map<String, MediaEntry> byId) {
  final cut = id.split('|');
  if (cut.length < 2) {
    return null;
  }
  return byId[cut.first];
}

class OpenEpisode {
  const OpenEpisode({
    required this.entry,
    required this.title,
    required this.ms,
    this.season,
    this.number,
  });

  final MediaEntry entry;
  final String title;
  final int ms;
  final int? season;
  final int? number;
}
