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

/// İki koltuk. Aynı kaynak, ayrı favori, raf ve kaldığın yer.
class SeatStore extends ChangeNotifier {
  SeatStore();

  static const miran = 'miran';
  static const asmin = 'asmin';

  String _active = miran;
  var picked = false;
  var _loaded = false;
  final Map<String, _Seat> _seats = {
    miran: _Seat('Miran'),
    asmin: _Seat('Asmin'),
  };

  String get activeId => _active;

  String get activeName => _seats[_active]!.name;

  int get favoriteCount => _seats[_active]!.favorites.length;

  List<UserShelf> get shelves => [
    for (final shelf in _seats[_active]!.shelves) UserShelf(shelf.name, List.unmodifiable(shelf.ids)),
  ];

  bool isFavorite(String id) => _seats[_active]!.favorites.contains(id);

  List<MediaEntry> favoritesIn(List<MediaEntry> entries) {
    final marks = _seats[_active]!.favorites;
    return [for (final entry in entries) if (marks.contains(entry.id)) entry];
  }

  KeptSpot? spotOf(String id) => _seats[_active]!.spots[id];

  int? introOf(String id) => _seats[_active]!.intros[id];

  List<MediaEntry> spotsIn(List<MediaEntry> entries) {
    return recentIn(entries);
  }

  List<MediaEntry> recentIn(List<MediaEntry> entries) {
    final spots = _seats[_active]!.spots;
    final byId = {for (final entry in entries) entry.id: entry};
    final recent = <MediaEntry>[];
    final seen = <String>{};
    for (final id in spots.keys.toList().reversed) {
      if ((spots[id]?.ms ?? 0) <= 8000) {
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
    final spots = _seats[_active]!.spots;
    return {
      for (final item in spots.entries)
        if (item.value.done && !item.key.contains('|')) item.key,
    };
  }

  List<OpenEpisode> unfinishedEpisodes(List<MediaEntry> entries) {
    final spots = _seats[_active]!.spots;
    final byId = {for (final entry in entries) entry.id: entry};
    final open = <OpenEpisode>[];
    for (final id in spots.keys.toList().reversed) {
      final spot = spots[id];
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
    final spots = _seats[_active]!.spots;
    return [
      for (final entry in entries)
        if (spots[entry.id]?.frame != null) entry,
    ];
  }

  void pick(String id) {
    if (_seats[id] == null) {
      return;
    }
    _active = id;
    picked = true;
    notifyListeners();
    _save();
  }

  void reopen() {
    picked = false;
    notifyListeners();
  }

  Map<String, dynamic> carryBag() {
    final seat = _seats[_active]!;
    return {
      'favorites': seat.favorites.toList(),
      'spots': [
        for (final item in seat.spots.entries)
          {'id': item.key, 'title': item.value.title, 'ms': item.value.ms, 'done': item.value.done},
      ],
    };
  }

  void absorbBag(Map raw) {
    final seat = _seats[_active]!;
    final favorites = raw['favorites'];
    if (favorites is List) {
      seat.favorites.addAll(favorites.map((item) => '$item'));
    }
    final spots = raw['spots'];
    if (spots is List) {
      for (final item in spots) {
        if (item is! Map) {
          continue;
        }
        final id = item['id']?.toString() ?? '';
        if (id.isEmpty) {
          continue;
        }
        final previous = seat.spots.remove(id);
        seat.spots[id] = KeptSpot(
          title: item['title']?.toString() ?? previous?.title ?? '',
          ms: int.tryParse('${item['ms']}') ?? previous?.ms ?? 0,
          frame: previous?.frame,
          done: item['done'] == true || previous?.done == true,
        );
      }
    }
    notifyListeners();
    _save();
  }

  void toggleFavorite(String id) {
    final marks = _seats[_active]!.favorites;
    if (!marks.add(id)) {
      marks.remove(id);
    }
    notifyListeners();
    _save();
  }

  void keepSpot(String id, {required String title, required int ms, bool done = false}) {
    final seat = _seats[_active]!;
    final previous = seat.spots.remove(id);
    seat.spots[id] = KeptSpot(title: title, ms: ms, frame: previous?.frame, done: done);
    notifyListeners();
    _save();
  }

  Future<void> keepFrame(String id, {required String title, required Uint8List bytes}) async {
    try {
      final folder = await _folder();
      final file = File('${folder.path}/${_safe(id)}.jpg');
      await file.writeAsBytes(bytes, flush: true);
      final seat = _seats[_active]!;
      final previous = seat.spots.remove(id);
      seat.spots[id] = KeptSpot(
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
    _seats[_active]!.intros[id] = ms;
    notifyListeners();
    _save();
  }

  void createShelf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final shelves = _seats[_active]!.shelves;
    for (final shelf in shelves) {
      if (shelf.name.toLowerCase() == trimmed.toLowerCase()) {
        return;
      }
    }
    shelves.add(_Shelf(trimmed, []));
    notifyListeners();
    _save();
  }

  void addToShelf(String name, String id) {
    for (final shelf in _seats[_active]!.shelves) {
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
      final file = File('${(await _folder()).path}/koltuklar.json');
      if (!file.existsSync()) {
        return;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map || picked) {
        return;
      }
      final active = decoded['active']?.toString();
      if (_seats.containsKey(active)) {
        _active = active!;
      }
      final seats = decoded['seats'];
      if (seats is Map) {
        for (final id in _seats.keys) {
          final raw = seats[id];
          if (raw is Map) {
            _seats[id] = _Seat.fromJson(_seats[id]!.name, raw);
          }
        }
      }
      picked = decoded['picked'] == true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final folder = await _folder();
      final file = File('${folder.path}/koltuklar.json');
      await file.writeAsString(
        jsonEncode({
          'active': _active,
          'picked': picked,
          'seats': {for (final id in _seats.keys) id: _seats[id]!.toJson()},
        }),
      );
    } catch (_) {}
  }

  Future<Directory> _folder() async {
    final support = await getApplicationSupportDirectory();
    final folder = Directory('${support.path}/koltuk');
    if (!folder.existsSync()) {
      await folder.create(recursive: true);
    }
    return folder;
  }
}

class _Shelf {
  _Shelf(this.name, this.ids);

  final String name;
  final List<String> ids;
}

class _Seat {
  _Seat(this.name);

  final String name;
  final Set<String> favorites = {};
  final Map<String, KeptSpot> spots = {};
  final Map<String, int> intros = {};
  final List<_Shelf> shelves = [];

  Map<String, dynamic> toJson() {
    return {
      'favorites': favorites.toList(),
      'intros': intros,
      'shelves': [
        for (final shelf in shelves) {'name': shelf.name, 'ids': shelf.ids},
      ],
      'spots': {
        for (final item in spots.entries)
          item.key: {
            'title': item.value.title,
            'ms': item.value.ms,
            'frame': ?item.value.frame,
            if (item.value.done) 'done': true,
          },
      },
    };
  }

  factory _Seat.fromJson(String name, Map raw) {
    final seat = _Seat(name);
    final favorites = raw['favorites'];
    if (favorites is List) {
      seat.favorites.addAll(favorites.map((item) => '$item'));
    }
    final intros = raw['intros'];
    if (intros is Map) {
      for (final item in intros.entries) {
        final ms = int.tryParse('${item.value}');
        if (ms != null) {
          seat.intros['${item.key}'] = ms;
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
        seat.shelves.add(
          _Shelf(shelfName, [if (ids is List) ...ids.map((id) => '$id')]),
        );
      }
    }
    final spots = raw['spots'];
    if (spots is Map) {
      for (final item in spots.entries) {
        final value = item.value;
        if (value is! Map) {
          continue;
        }
        seat.spots['${item.key}'] = KeptSpot(
          title: value['title']?.toString() ?? '',
          ms: int.tryParse('${value['ms']}') ?? 0,
          frame: value['frame']?.toString(),
          done: value['done'] == true,
        );
      }
    }
    return seat;
  }
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
