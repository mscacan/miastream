import 'dart:convert';
import 'dart:io';

import '../library/user_source.dart';
import '../shell/shell_section.dart';
import 'artwork.dart';
import 'media_entry.dart';

const _agent =
    'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3';

class _Door {
  const _Door({required this.portal, required this.token, required this.mac});

  final Uri portal;
  final String token;
  final String mac;
}

final _doors = <String, _Door>{};

List<Uri> stalkerPortals(String raw) {
  var text = raw.trim();
  if (text.isEmpty) {
    throw SourceLoadException('Portal boş');
  }
  if (!text.contains('://')) {
    text = 'http://$text';
  }
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) {
    throw SourceLoadException('Portal okunamadı');
  }
  final origin = Uri(
    scheme: uri.scheme.isEmpty ? 'http' : uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  );
  if (uri.path.endsWith('.php')) {
    return [uri.replace(query: '')];
  }
  return [
    origin.replace(path: '/stalker_portal/server/load.php'),
    origin.replace(path: '/server/load.php'),
    origin.replace(path: '/portal.php'),
    origin.replace(path: '/c/portal.php'),
  ];
}

String normalizeMac(String raw) {
  final hex = raw.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
  if (hex.length != 12) {
    throw SourceLoadException('MAC adresi 12 karakter olmalı');
  }
  return [
    for (var i = 0; i < 12; i += 2) hex.substring(i, i + 2),
  ].join(':');
}

Future<List<MediaEntry>> loadStalker(UserSource source) async {
  final door = await _openDoor(source);
  final genres = await _genres(door);
  final live = await _channels(door, source.id, genres);
  final movies = await _pages(door, source.id, 'vod', ShellSection.movies, genres);
  final series = await _pages(door, source.id, 'series', ShellSection.series, genres);
  return [...live, ...movies, ...series];
}

Future<String> resolveStalkerLink(UserSource source, String cmd, {String? kind}) async {
  final door = await _openDoor(source);
  final kinds = <String>[
    if (kind != null && kind.isNotEmpty) kind,
    'itv',
    'vod',
    'series',
  ];
  final seen = <String>{};
  for (final type in kinds) {
    if (!seen.add(type)) {
      continue;
    }
    try {
      final js = await _call(door, {
        'type': type,
        'action': 'create_link',
        'cmd': cmd,
        'series': '',
        'forced_storage': '0',
        'disable_ad': '0',
        'download': '0',
      });
      final link = _cleanCmd(_cmdOf(js));
      if (link.startsWith('http://') || link.startsWith('https://')) {
        return link;
      }
    } catch (_) {}
  }
  final direct = _cleanCmd(cmd);
  if (direct.startsWith('http://') || direct.startsWith('https://')) {
    return direct;
  }
  throw SourceLoadException('Yayın adresi çıkmadı');
}

Future<_Door> _openDoor(UserSource source) async {
  final cached = _doors[source.id];
  if (cached != null) {
    return cached;
  }
  final mac = normalizeMac(source.mac);
  Object? failure;
  for (final portal in stalkerPortals(source.value)) {
    try {
      final js = await _call(
        _Door(portal: portal, token: '', mac: mac),
        {'type': 'stb', 'action': 'handshake', 'token': '', 'prehash': '0'},
      );
      final token = js is Map ? '${js['token'] ?? ''}'.trim() : '';
      if (token.isEmpty) {
        continue;
      }
      final door = _Door(portal: portal, token: token, mac: mac);
      try {
        await _call(door, {'type': 'stb', 'action': 'get_profile'});
      } catch (_) {}
      _doors[source.id] = door;
      return door;
    } catch (error) {
      failure = error;
    }
  }
  if (failure is SourceLoadException) {
    throw failure;
  }
  throw SourceLoadException('Portal yanıt vermedi');
}

Future<Map<String, String>> _genres(_Door door) async {
  final names = <String, String>{};
  try {
    final js = await _call(door, {'type': 'itv', 'action': 'get_genres'});
    final rows = _rows(js);
    for (final row in rows) {
      final id = '${row['id'] ?? ''}'.trim();
      final title = '${row['title'] ?? row['name'] ?? ''}'.trim();
      if (id.isNotEmpty && title.isNotEmpty) {
        names[id] = title;
      }
    }
  } catch (_) {}
  return names;
}

Future<List<MediaEntry>> _channels(_Door door, String sourceId, Map<String, String> genres) async {
  dynamic js;
  try {
    js = await _call(door, {'type': 'itv', 'action': 'get_all_channels'});
  } catch (_) {
    js = await _call(door, {
      'type': 'itv',
      'action': 'get_ordered_list',
      'genre': '*',
      'p': '1',
    });
  }
  return _read(js, sourceId: sourceId, section: ShellSection.live, kind: 'itv', genres: genres);
}

Future<List<MediaEntry>> _pages(
  _Door door,
  String sourceId,
  String type,
  ShellSection section,
  Map<String, String> genres,
) async {
  final entries = <MediaEntry>[];
  for (var page = 1; page <= 4; page++) {
    try {
      final js = await _call(door, {
        'type': type,
        'action': 'get_ordered_list',
        'genre': '*',
        'p': '$page',
        'sortby': 'added',
      });
      final batch = _read(js, sourceId: sourceId, section: section, kind: type, genres: genres);
      if (batch.isEmpty) {
        break;
      }
      entries.addAll(batch);
    } catch (_) {
      break;
    }
  }
  return entries;
}

List<MediaEntry> _read(
  dynamic js, {
  required String sourceId,
  required ShellSection section,
  required String kind,
  required Map<String, String> genres,
}) {
  final entries = <MediaEntry>[];
  for (final row in _rows(js)) {
    if (entries.length >= 1500) {
      break;
    }
    final cmd = '${row['cmd'] ?? ''}'.trim();
    if (cmd.isEmpty) {
      continue;
    }
    final name = '${row['name'] ?? row['title'] ?? ''}'.trim();
    final id = '${row['id'] ?? entries.length + 1}'.trim();
    final genreId = '${row['tv_genre_id'] ?? row['category_id'] ?? ''}'.trim();
    final logo = httpArtwork('${row['logo'] ?? row['screenshot_uri'] ?? ''}');
    final epg = '${row['xmltv_id'] ?? row['epg_id'] ?? ''}'.trim();
    entries.add(
      MediaEntry(
        id: '$sourceId-${section.name}-$id',
        title: name.isEmpty ? 'Kayıt' : name,
        section: section,
        sourceId: sourceId,
        group: genres[genreId] ?? (section == ShellSection.live ? 'Canlı' : 'Kayıtlar'),
        artwork: logo,
        epgId: epg.isEmpty ? null : epg,
        playCmd: cmd,
        linkKind: kind,
      ),
    );
  }
  return entries;
}

List<Map> _rows(dynamic js) {
  if (js is List) {
    return [for (final item in js) if (item is Map) item];
  }
  if (js is Map) {
    final data = js['data'];
    if (data is List) {
      return [for (final item in data) if (item is Map) item];
    }
  }
  return const [];
}

String _cmdOf(dynamic js) {
  if (js is Map) {
    return '${js['cmd'] ?? ''}';
  }
  return '';
}

String _cleanCmd(String raw) {
  return raw.trim().replaceFirst(RegExp(r'^(ffmpeg|ffrt|auto)\s+'), '');
}

Future<dynamic> _call(_Door door, Map<String, String> query) async {
  final uri = door.portal.replace(
    queryParameters: {...query, 'JsHttpRequest': '1-xml'},
  );
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 12);
  try {
    final request = await client.getUrl(uri).timeout(const Duration(seconds: 12));
    request.headers.set(HttpHeaders.userAgentHeader, _agent);
    request.headers.set('X-User-Agent', 'Model: MAG250; Link: WiFi');
    var cookie = 'mac=${door.mac}; stb_lang=en; timezone=Europe/Istanbul';
    if (door.token.isNotEmpty) {
      cookie = '$cookie; token=${door.token}';
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${door.token}');
    }
    request.headers.set(HttpHeaders.cookieHeader, cookie);
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode >= 400) {
      throw SourceLoadException('Portal yanıt vermedi');
    }
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['js'] != null) {
      return decoded['js'];
    }
    return decoded;
  } on SourceLoadException {
    rethrow;
  } catch (_) {
    throw SourceLoadException('Portal yanıt vermedi');
  } finally {
    client.close(force: true);
  }
}
