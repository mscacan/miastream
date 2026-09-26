import 'dart:convert';
import 'dart:io';

import '../library/user_source.dart';
import '../shell/shell_section.dart';
import 'artwork.dart';
import 'm3u_parser.dart';
import 'media_entry.dart';
import 'title_facts.dart';
import 'stalker_api.dart';
import 'xtream_api.dart';

typedef LoadPulse = void Function(String label, int count);

class SourceLoader {
  const SourceLoader();

  Future<List<MediaEntry>> load(UserSource source, {LoadPulse? onPulse}) {
    return loadUserSource(source, onPulse: onPulse);
  }

  Future<List<Episode>> episodes(UserSource source, int seriesId) {
    return loadEpisodes(source, seriesId);
  }

  Future<TitleBrief> describe(UserSource source, MediaEntry entry) {
    return describeTitle(source, entry);
  }
}

Future<List<MediaEntry>> loadUserSource(UserSource source, {LoadPulse? onPulse}) async {
  switch (source.kind) {
    case UserSourceKind.m3u:
      return _loadM3u(source, onPulse: onPulse);
    case UserSourceKind.xtream:
      return _loadXtream(source, onPulse: onPulse);
    case UserSourceKind.stalker:
      onPulse?.call('Portal okunuyor', 0);
      final entries = await loadStalker(source);
      onPulse?.call('Portal hazır', entries.length);
      return entries;
  }
}

Future<List<MediaEntry>> _loadM3u(UserSource source, {LoadPulse? onPulse}) async {
  onPulse?.call('Liste okunuyor', 0);
  final raw = source.value.trim();
  if (raw.startsWith('#EXTM3U') || raw.startsWith('#EXTINF')) {
    final entries = parseM3u(raw, sourceId: source.id);
    onPulse?.call('Liste hazır', entries.length);
    return entries;
  }
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme) {
    throw SourceLoadException('Liste adresi okunamadı');
  }
  final body = await fetchText(uri);
  if (!body.contains('#EXTM3U') && !body.contains('#EXTINF')) {
    return [
      MediaEntry(
        id: '${source.id}-1',
        title: source.label,
        url: raw,
        section: ShellSection.live,
        sourceId: source.id,
      ),
    ];
  }
  final entries = parseM3u(body, sourceId: source.id);
  onPulse?.call('Liste hazır', entries.length);
  return entries;
}

Future<List<MediaEntry>> _loadXtream(UserSource source, {LoadPulse? onPulse}) async {
  onPulse?.call('Giriş doğrulanıyor', 0);
  final base = xtreamBase(source.value);
  final user = source.username;
  final pass = source.password;
  final root = await fetchJson(xtreamApi(base, user, pass));
  if (root is! Map) {
    throw SourceLoadException('Sunucu yanıtı okunamadı');
  }
  final info = root['user_info'];
  final auth = info is Map ? info['auth'] : null;
  if (auth != 1 && auth != '1') {
    throw SourceLoadException('Giriş kabul edilmedi');
  }

  Object? failure;
  Future<List<MediaEntry>> take(Future<List<MediaEntry>> pending) async {
    try {
      return await pending;
    } catch (error) {
      failure ??= error;
      return const [];
    }
  }

  final live = await take(_live(base, user, pass, source.id));
  onPulse?.call('Canlı yayınlar', live.length);
  final movies = await take(_movies(base, user, pass, source.id));
  onPulse?.call('Filmler', live.length + movies.length);
  final series = await take(_series(base, user, pass, source.id));
  final entries = <MediaEntry>[...live, ...movies, ...series];
  onPulse?.call('İçerikler hazır', entries.length);
  if (entries.isEmpty) {
    final error = failure;
    if (error is SourceLoadException) {
      throw error;
    }
    if (error != null) {
      throw SourceLoadException('Liste okunamadı');
    }
  }
  return entries;
}

Future<List<MediaEntry>> _live(Uri base, String user, String pass, String sourceId) async {
  final list = await fetchJson(xtreamApi(base, user, pass, action: 'get_live_streams'));
  final categories = await _categoryNames(base, user, pass, 'get_live_categories');
  return _streams(
    list,
    base: base,
    categories: categories,
    sourceId: sourceId,
    section: ShellSection.live,
    idKey: 'stream_id',
    fallbackGroup: 'Canlı',
    urlFor: (id, item, resolved) => _xtreamUrl(base, user, pass, id, item, resolved),
  );
}

Future<List<MediaEntry>> _movies(Uri base, String user, String pass, String sourceId) async {
  final list = await fetchJson(xtreamApi(base, user, pass, action: 'get_vod_streams'));
  final categories = await _categoryNames(base, user, pass, 'get_vod_categories');
  return _streams(
    list,
    base: base,
    categories: categories,
    sourceId: sourceId,
    section: ShellSection.movies,
    idKey: 'stream_id',
    fallbackGroup: 'Filmler',
    urlFor: (id, item, resolved) => _xtreamUrl(base, user, pass, id, item, resolved),
  );
}

Future<List<MediaEntry>> _series(Uri base, String user, String pass, String sourceId) async {
  final list = await fetchJson(xtreamApi(base, user, pass, action: 'get_series'));
  final categories = await _categoryNames(base, user, pass, 'get_series_categories');
  if (list is! List) {
    return const [];
  }
  final entries = <MediaEntry>[];
  for (final item in list) {
    if (item is! Map) {
      continue;
    }
    final seriesId = _asInt(item['series_id']);
    if (seriesId == null) {
      continue;
    }
    if (xtreamListedSection(item, ShellSection.series) != ShellSection.series) {
      continue;
    }
    final facts = factsFromItem(item, base: base);
    entries.add(
      MediaEntry(
        id: '$sourceId-series-$seriesId',
        title: item['name']?.toString().trim().isNotEmpty == true
            ? item['name'].toString()
            : 'Dizi',
        section: ShellSection.series,
        sourceId: sourceId,
        seriesId: seriesId,
        group: _groupName(item, categories, 'Diziler'),
        artwork: artworkFrom(item, base: base),
        plot: facts.plot,
        genre: facts.genre,
        year: facts.year,
        minutes: facts.minutes,
        rating: facts.rating,
        director: facts.director,
        cast: facts.cast,
        backdrop: facts.backdrop,
      ),
    );
  }
  return entries;
}

List<MediaEntry> _streams(
  dynamic list, {
  required Uri base,
  required Map<String, String> categories,
  required String sourceId,
  required ShellSection section,
  required String idKey,
  required String fallbackGroup,
  required String Function(int id, Map item, ShellSection resolved) urlFor,
}) {
  if (list is! List) {
    return const [];
  }
  final entries = <MediaEntry>[];
  for (final item in list) {
    if (item is! Map) {
      continue;
    }
    final id = _asInt(item[idKey]);
    if (id == null) {
      continue;
    }
    final resolved = xtreamListedSection(item, section);
    if (resolved != ShellSection.live &&
        resolved != ShellSection.movies &&
        resolved != ShellSection.series) {
      continue;
    }
    final name = item['name']?.toString().trim();
    final fallback = resolved == section ? fallbackGroup : _fallbackFor(resolved);
    final facts = factsFromItem(item, base: base);
    entries.add(
      MediaEntry(
        id: '$sourceId-${resolved.name}-$id',
        title: (name == null || name.isEmpty) ? 'Kayıt' : name,
        url: urlFor(id, item, resolved),
        section: resolved,
        sourceId: sourceId,
        streamId: resolved == ShellSection.live || resolved == ShellSection.movies ? id : null,
        group: _groupName(item, resolved == section ? categories : const {}, fallback),
        artwork: artworkFrom(item, base: base),
        epgId: _epgId(item),
        archiveHours: resolved == ShellSection.live ? _archiveHours(item) : null,
        plot: facts.plot,
        genre: facts.genre,
        year: facts.year,
        minutes: facts.minutes,
        rating: facts.rating,
        director: facts.director,
        cast: facts.cast,
        backdrop: facts.backdrop,
      ),
    );
  }
  return entries;
}

String _fallbackFor(ShellSection section) {
  return switch (section) {
    ShellSection.movies => 'Filmler',
    ShellSection.series => 'Diziler',
    _ => 'Canlı',
  };
}

String _xtreamUrl(Uri base, String user, String pass, int id, Map item, ShellSection section) {
  if (section == ShellSection.movies) {
    final ext = item['container_extension']?.toString() ?? 'mp4';
    return xtreamMovieUrl(base, user, pass, id, ext);
  }
  return xtreamLiveUrl(base, user, pass, id);
}

Future<TitleBrief> describeTitle(UserSource source, MediaEntry entry) async {
  if (source.kind != UserSourceKind.xtream) {
    return TitleBrief(
      plot: entry.plot,
      genre: entry.genre,
      year: entry.year,
      minutes: entry.minutes,
      rating: entry.rating,
      director: entry.director,
      cast: entry.cast,
      backdrop: entry.backdrop ?? entry.artwork,
    );
  }
  final base = xtreamBase(source.value);
  if (entry.section == ShellSection.series && entry.seriesId != null) {
    final root = await fetchJson(
      xtreamApi(
        base,
        source.username,
        source.password,
        action: 'get_series_info',
        extra: {'series_id': '${entry.seriesId}'},
      ),
    );
    if (root is! Map) {
      throw SourceLoadException('Ayrıntı okunamadı');
    }
    final info = root['info'];
    final facts = factsFromItem(info is Map ? info : const {}, base: base);
    final episodes = _readEpisodes(
      root['episodes'],
      base,
      source.username,
      source.password,
      facts.backdrop ?? artworkFrom(info is Map ? info : const {}, base: base),
    );
    return TitleBrief(
      plot: facts.plot,
      genre: facts.genre,
      year: facts.year,
      minutes: facts.minutes,
      rating: facts.rating,
      director: facts.director,
      cast: facts.cast,
      backdrop: facts.backdrop,
      episodes: episodes,
    ).fillFrom(entry);
  }
  final streamId = entry.streamId;
  if (entry.section == ShellSection.movies && streamId != null) {
    final root = await fetchJson(
      xtreamApi(
        base,
        source.username,
        source.password,
        action: 'get_vod_info',
        extra: {'vod_id': '$streamId'},
      ),
    );
    if (root is! Map) {
      throw SourceLoadException('Ayrıntı okunamadı');
    }
    final info = root['info'];
    final facts = factsFromItem(info is Map ? info : const {}, base: base);
    return facts.fillFrom(entry);
  }
  return TitleBrief(
    plot: entry.plot,
    genre: entry.genre,
    year: entry.year,
    minutes: entry.minutes,
    rating: entry.rating,
    director: entry.director,
    cast: entry.cast,
    backdrop: entry.backdrop ?? entry.artwork,
  );
}

Future<List<Episode>> loadEpisodes(UserSource source, int seriesId) async {
  final base = xtreamBase(source.value);
  final root = await fetchJson(
    xtreamApi(
      base,
      source.username,
      source.password,
      action: 'get_series_info',
      extra: {'series_id': '$seriesId'},
    ),
  );
  if (root is! Map) {
    throw SourceLoadException('Bölüm listesi okunamadı');
  }
  final info = root['info'];
  final seriesArt = info is Map ? artworkFrom(info, base: base) : null;
  return _readEpisodes(
    root['episodes'],
    base,
    source.username,
    source.password,
    seriesArt,
  );
}

List<Episode> _readEpisodes(
  dynamic node,
  Uri base,
  String user,
  String pass,
  String? seriesArt,
) {
  final episodes = <Episode>[];
  void add(Map item, int? season) {
    final episode = _episodeFrom(item, season, base, user, pass, seriesArt);
    if (episode != null) {
      episodes.add(episode);
    }
  }

  if (node is List) {
    for (final item in node) {
      if (item is Map) {
        add(item, _asInt(item['season']));
      }
    }
    return episodes;
  }
  if (node is! Map) {
    return episodes;
  }
  if (_looksLikeEpisode(node)) {
    add(node, _asInt(node['season']));
    return episodes;
  }
  final keys = node.keys.toList()
    ..sort((a, b) => (_asInt(a) ?? 1 << 20).compareTo(_asInt(b) ?? 1 << 20));
  for (final key in keys) {
    final season = _asInt(key);
    final value = node[key];
    if (value is List) {
      for (final item in value) {
        if (item is Map) {
          add(item, season ?? _asInt(item['season']));
        }
      }
    } else if (value is Map && _looksLikeEpisode(value)) {
      add(value, season ?? _asInt(value['season']));
    }
  }
  return episodes;
}

bool _looksLikeEpisode(Map item) {
  return item['id'] != null &&
      (item['container_extension'] != null || item['episode_num'] != null);
}

Episode? _episodeFrom(
  Map item,
  int? season,
  Uri base,
  String user,
  String pass,
  String? seriesArt,
) {
  final id = item['id']?.toString() ?? '';
  if (id.isEmpty) {
    return null;
  }
  final ext = item['container_extension']?.toString() ?? 'mkv';
  final number = _asInt(item['episode_num']);
  final title = item['title']?.toString().trim();
  final fallback = number == null ? 'Bölüm' : 'Bölüm $number';
  return Episode(
    title: (title == null || title.isEmpty) ? fallback : title,
    url: xtreamEpisodeUrl(base, user, pass, id, ext),
    season: _asInt(item['season']) ?? season,
    number: number,
    artwork: artworkFrom(item, base: base) ?? seriesArt,
  );
}

Future<Map<String, String>> _categoryNames(
  Uri base,
  String user,
  String pass,
  String action,
) async {
  try {
    final list = await fetchJson(xtreamApi(base, user, pass, action: action));
    if (list is! List) {
      return const {};
    }
    final names = <String, String>{};
    for (final item in list) {
      if (item is! Map) {
        continue;
      }
      final id = item['category_id']?.toString();
      final name = item['category_name']?.toString().trim();
      if (id == null || id.isEmpty || name == null || name.isEmpty) {
        continue;
      }
      names[id] = name;
    }
    return names;
  } catch (_) {
    return const {};
  }
}

String _groupName(Map item, Map<String, String> categories, String fallback) {
  final named = item['category_name']?.toString().trim();
  if (named != null && named.isNotEmpty) {
    return named;
  }
  final id = item['category_id']?.toString();
  final mapped = id == null ? null : categories[id];
  if (mapped != null && mapped.isNotEmpty) {
    return mapped;
  }
  return fallback;
}

String? _epgId(Map item) {
  final raw = '${item['epg_channel_id'] ?? ''}'.trim();
  if (raw.isEmpty) {
    return null;
  }
  return raw;
}

int? _archiveHours(Map item) {
  final flag = '${item['tv_archive'] ?? ''}'.trim().toLowerCase();
  if (flag != '1' && flag != 'true') {
    return null;
  }
  final hours = int.tryParse('${item['tv_archive_duration'] ?? ''}');
  if (hours == null || hours <= 0) {
    return 24;
  }
  return hours;
}

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse('$value');
}

Future<String> fetchText(Uri uri) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.getUrl(uri).timeout(const Duration(seconds: 20));
    request.headers.set(HttpHeaders.userAgentHeader, 'MiaStream');
    final response = await request.close().timeout(const Duration(seconds: 40));
    if (response.statusCode >= 400) {
      throw SourceLoadException('Sunucu yanıt vermedi');
    }
    final body = await response.transform(utf8.decoder).join();
    if (body.length > 30 * 1024 * 1024) {
      throw SourceLoadException('Liste çok büyük');
    }
    return body;
  } on SourceLoadException {
    rethrow;
  } catch (_) {
    throw SourceLoadException('Liste okunamadı');
  } finally {
    client.close(force: true);
  }
}

Future<dynamic> fetchJson(Uri uri) async {
  try {
    return jsonDecode(await fetchText(uri));
  } on SourceLoadException {
    rethrow;
  } catch (_) {
    throw SourceLoadException('Sunucu yanıtı okunamadı');
  }
}
