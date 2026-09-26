import '../shell/shell_section.dart';
import 'media_entry.dart';

Uri xtreamBase(String raw) {
  var text = raw.trim();
  if (text.isEmpty) {
    throw SourceLoadException('Sunucu boş');
  }
  if (!text.contains('://')) {
    text = 'http://$text';
  }
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) {
    throw SourceLoadException('Sunucu okunamadı');
  }
  return Uri(
    scheme: uri.scheme.isEmpty ? 'http' : uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  );
}

Uri xtreamApi(
  Uri base,
  String username,
  String password, {
  String? action,
  Map<String, String> extra = const {},
}) {
  return base.replace(
    path: '/player_api.php',
    queryParameters: {
      'username': username,
      'password': password,
      'action': ?action,
      ...extra,
    },
  );
}

String xtreamLiveUrl(Uri base, String username, String password, int streamId) {
  return _join(base, 'live/${_seg(username)}/${_seg(password)}/$streamId.m3u8');
}

String xtreamGuideUrl(Uri base, String username, String password) {
  return base
      .replace(
        path: '/xmltv.php',
        queryParameters: {'username': username, 'password': password},
      )
      .toString();
}

String xtreamTimeshiftUrl(
  Uri base,
  String username,
  String password,
  int streamId,
  DateTime start,
  int durationMinutes,
) {
  final local = start.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  final stamp =
      '${local.year}-${two(local.month)}-${two(local.day)}:${two(local.hour)}-${two(local.minute)}';
  return base
      .replace(
        path: '/streaming/timeshift.php',
        queryParameters: {
          'username': username,
          'password': password,
          'stream': '$streamId',
          'start': stamp,
          'duration': '$durationMinutes',
        },
      )
      .toString();
}

String xtreamMovieUrl(
  Uri base,
  String username,
  String password,
  int streamId,
  String extension,
) {
  return _join(
    base,
    'movie/${_seg(username)}/${_seg(password)}/$streamId.${_ext(extension)}',
  );
}

String xtreamEpisodeUrl(
  Uri base,
  String username,
  String password,
  String episodeId,
  String extension,
) {
  return _join(
    base,
    'series/${_seg(username)}/${_seg(password)}/${_seg(episodeId)}.${_ext(extension)}',
  );
}

/// Sunucunun işaretine göre sayfa. Addaki "Sinema" kelimesi türü değiştirmez.
ShellSection xtreamListedSection(Map item, ShellSection listedAs) {
  final type = '${item['stream_type'] ?? ''}'.trim().toLowerCase();
  if (type == 'live') {
    return ShellSection.live;
  }
  if (type == 'movie' || type == 'vod') {
    return ShellSection.movies;
  }
  if (type == 'series') {
    return ShellSection.series;
  }

  final extension = '${item['container_extension'] ?? ''}'.trim();
  final guide = '${item['epg_channel_id'] ?? ''}'.trim();
  final looksLive = guide.isNotEmpty || item.containsKey('tv_archive');
  if (listedAs != ShellSection.live && looksLive && extension.isEmpty) {
    return ShellSection.live;
  }
  return listedAs;
}

String _join(Uri base, String path) {
  final origin = base.toString().replaceAll(RegExp(r'/+$'), '');
  return '$origin/$path';
}

String _seg(String value) => Uri.encodeComponent(value);

String _ext(String raw) {
  final cleaned = raw.trim().replaceAll('.', '');
  return cleaned.isEmpty ? 'mp4' : cleaned;
}
