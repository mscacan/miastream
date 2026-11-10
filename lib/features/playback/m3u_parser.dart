import '../shell/shell_section.dart';
import 'artwork.dart';
import 'media_entry.dart';

List<MediaEntry> parseM3u(String body, {required String sourceId}) {
  final lines = body.split(RegExp(r'\r?\n'));
  final items = <MediaEntry>[];
  String? title;
  String? group;
  String? logo;
  String? epgId;
  String? guide;
  var archiveHours = 0;

  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) {
      continue;
    }
    if (line.startsWith('#EXTM3U')) {
      guide = _attr(line, 'url-tvg') ?? _attr(line, 'x-tvg-url');
      continue;
    }
    if (line.startsWith('#EXTINF')) {
      group = _attr(line, 'group-title');
      logo = _attr(line, 'tvg-logo');
      epgId = _attr(line, 'tvg-id');
      archiveHours = int.tryParse(_attr(line, 'tvg-rec') ?? '') ?? 0;
      final comma = line.lastIndexOf(',');
      final name = comma >= 0 ? line.substring(comma + 1).trim() : '';
      title = name.isEmpty ? null : name;
      continue;
    }
    if (line.startsWith('#')) {
      continue;
    }
    if (!_isAbsoluteHttp(line)) {
      title = null;
      group = null;
      logo = null;
      epgId = null;
      archiveHours = 0;
      continue;
    }
    final index = items.length + 1;
    items.add(
      MediaEntry(
        id: '$sourceId-$index',
        title: title ?? 'Kayıt $index',
        url: line,
        section: sectionFor(group, line),
        sourceId: sourceId,
        group: (group == null || group.isEmpty) ? 'Kayıtlar' : group,
        artwork: httpArtwork(logo),
        epgId: (epgId == null || epgId.isEmpty) ? null : epgId,
        guideUrl: guide,
        archiveHours: archiveHours > 0 ? archiveHours : null,
      ),
    );
    title = null;
    group = null;
    logo = null;
    epgId = null;
    archiveHours = 0;
  }
  return items;
}

ShellSection sectionFor(String? group, String url) {
  final path = url.toLowerCase();
  if (path.contains('/live/')) {
    return ShellSection.live;
  }
  if (path.contains('/movie/')) {
    return ShellSection.movies;
  }
  if (path.contains('/series/')) {
    return ShellSection.series;
  }
  if (path.contains('.m3u8') || path.contains('.ts')) {
    return ShellSection.live;
  }
  final text = (group ?? '').toLowerCase();
  if (text.contains('dizi') || text.contains('series') || text.contains('season')) {
    return ShellSection.series;
  }
  if (text.contains('film') || text.contains('movie') || text.contains('sinema')) {
    return ShellSection.movies;
  }
  return ShellSection.live;
}

bool _isAbsoluteHttp(String line) {
  final uri = Uri.tryParse(line);
  if (uri == null) {
    return false;
  }
  return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
}

final _attrPatterns = <String, (RegExp, RegExp, RegExp)>{};

String? _attr(String line, String name) {
  final (quotedPattern, singlePattern, barePattern) = _attrPatterns.putIfAbsent(
    name,
    () => (
      RegExp('$name\\s*=\\s*"([^"]*)"', caseSensitive: false),
      RegExp("$name\\s*=\\s*'([^']*)'", caseSensitive: false),
      RegExp('$name\\s*=\\s*([^\\s,]*)', caseSensitive: false),
    ),
  );
  final quoted = quotedPattern.firstMatch(line);
  if (quoted != null) {
    return quoted.group(1)?.trim();
  }
  final single = singlePattern.firstMatch(line);
  if (single != null) {
    return single.group(1)?.trim();
  }
  final bare = barePattern.firstMatch(line);
  final value = bare?.group(1)?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}
