import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:miastream/features/browse/cover_store.dart';
import 'package:miastream/features/epg/guide.dart';
import 'package:miastream/features/playback/artwork.dart';
import 'package:miastream/features/playback/data_save.dart';
import 'package:miastream/features/playback/m3u_parser.dart';
import 'package:miastream/features/playback/media_entry.dart';
import 'package:miastream/features/playback/stalker_api.dart';
import 'package:miastream/features/playback/title_facts.dart';
import 'package:miastream/features/playback/track_labels.dart';
import 'package:miastream/features/playback/xtream_api.dart';
import 'package:miastream/features/shell/shell_section.dart';

void main() {
  test('m3u yalnızca yapıştırılan satırları okur', () {
    const body = '''
#EXTM3U
#EXTINF:-1 group-title="Filmler",Ornek Film
https://ornek.invalid/film.mp4
#EXTINF:-1 group-title="Canlı",Ornek Kanal
https://ornek.invalid/canli.m3u8
''';

    final items = parseM3u(body, sourceId: 'kaynak');

    expect(items, hasLength(2));
    expect(items.first.title, 'Ornek Film');
    expect(items.first.section, ShellSection.movies);
    expect(items.last.section, ShellSection.live);
    expect(items.last.url, 'https://ornek.invalid/canli.m3u8');
    expect(items.first.artwork, isNull);
  });

  test('sinema adındaki canlı yayın film sayfasına düşmez', () {
    const body = '''
#EXTM3U
#EXTINF:-1 group-title="SİNEMA",Sinema TV
https://ornek.invalid/live/1.m3u8
#EXTINF:-1 group-title="SİNEMA",Ornek Film
https://ornek.invalid/movie/2.mp4
''';

    final items = parseM3u(body, sourceId: 'kaynak');

    expect(items.first.section, ShellSection.live);
    expect(items.last.section, ShellSection.movies);
    expect(
      xtreamListedSection({'name': 'SİNEMA', 'stream_type': 'live'}, ShellSection.movies),
      ShellSection.live,
    );
    expect(
      xtreamListedSection({'name': 'SİNEMA', 'stream_type': 'movie'}, ShellSection.live),
      ShellSection.movies,
    );
    expect(
      xtreamListedSection(
        {'name': 'Sinema 1', 'epg_channel_id': 'sinema.tr'},
        ShellSection.movies,
      ),
      ShellSection.live,
    );
  });

  test('m3u kapak adresini tvg-logo alanından alır', () {
    const body = '''
#EXTM3U
#EXTINF:-1 tvg-logo="https://ornek.invalid/afis.jpg" group-title="Filmler",Ornek Film
https://ornek.invalid/film.mp4
''';

    final items = parseM3u(body, sourceId: 'kaynak');

    expect(items.single.artwork, 'https://ornek.invalid/afis.jpg');

    const bare = '''
#EXTM3U
#EXTINF:-1 tvg-logo='https://ornek.invalid/tek.png' group-title="Canlı",Kanal
https://ornek.invalid/live/a.m3u8
''';
    expect(parseM3u(bare, sourceId: 'k').single.artwork, 'https://ornek.invalid/tek.png');
  });

  test('görünen kapak iner, katalog bekletilmez', () async {
    final dir = await Directory.systemTemp.createTemp('mia-kapak');
    addTearDown(() => dir.delete(recursive: true));
    var calls = 0;
    Future<Uint8List?> fetch(String url) async {
      calls += 1;
      return Uint8List.fromList([0xFF, 0xD8, 0xFF, ...List<int>.filled(40, 0)]);
    }

    final first = CoverStore(fetch: fetch, folder: () async => dir);
    expect(first.busy, isFalse);
    await first.touch('https://ornek.invalid/a.jpg');
    expect(first.of('https://ornek.invalid/a.jpg'), isNotNull);
    expect(first.of('https://ornek.invalid/b.jpg'), isNull);
    expect(calls, 1);

    final second = CoverStore(fetch: fetch, folder: () async => dir);
    await second.touch('https://ornek.invalid/a.jpg');
    expect(calls, 1);
    expect(second.of('https://ornek.invalid/a.jpg'), isNotNull);
    first.dispose();
    second.dispose();
  });

  test('xtream adresi kullanıcının sunucusundan kurulur', () {
    final base = xtreamBase('ornek.invalid:8080');

    expect(
      xtreamLiveUrl(base, 'ada', 'gizli sifre', 12),
      'http://ornek.invalid:8080/live/ada/gizli%20sifre/12.m3u8',
    );
    expect(
      xtreamMovieUrl(base, 'ada', 'gizli', 3, 'mkv'),
      'http://ornek.invalid:8080/movie/ada/gizli/3.mkv',
    );
  });

  test('kapak adresi ve türkçe sıra', () {
    expect(
      httpArtwork('/kapak.jpg', base: Uri.parse('http://ornek.invalid:8080')),
      'http://ornek.invalid:8080/kapak.jpg',
    );
    expect(httpArtwork('ftp://ornek.invalid/a.jpg'), isNull);
    expect(
      artworkFrom({
        'stream_icon': 'https://ornek.invalid/logo.png',
      }),
      'https://ornek.invalid/logo.png',
    );

    final ordered = turkishFirst(
      ['English', 'Türkçe', 'Arabic'],
      (item) => prefersTurkish(null, item),
    );
    expect(ordered.first, 'Türkçe');

    const cue = PlaybackCue(
      title: 'Pilot',
      url: 'https://ornek.invalid/b.mkv',
      seriesTitle: 'Ada',
      season: 1,
      number: 2,
    );
    expect(cue.headline, 'Ada');
    expect(cue.detail, 'Sezon 1 · Bölüm 2 · Pilot');
    const spotted = PlaybackCue(
      id: 'dizi',
      title: 'Pilot',
      url: 'https://ornek.invalid/b.mkv',
      season: 1,
      number: 2,
    );
    expect(spotted.spotId, 'dizi|1|2');
    const film = PlaybackCue(id: 'film', title: 'Film', url: 'https://ornek.invalid/c.mkv');
    expect(film.spotId, 'film');
    expect(upperTr('iı'), 'İI');
    expect(matchesPreference('tr', null, 'Türkçe'), isTrue);
    expect(matchesPreference('en', 'English', 'Türkçe'), isFalse);
    final picked = pickPreferred(
      [('en', 'English'), ('tr', 'Türkçe')],
      'Türkçe',
      'English',
      (item) => item.$1,
      (item) => item.$2,
    );
    expect(picked?.$1, 'tr');
  });

  test('veri ayarı küçük boyu seçer', () {
    expect(hlsBitrateFor('Düşük'), 'min');
    expect(hlsBitrateFor('Orta'), '2500000');
    expect(hlsBitrateFor('Yüksek'), 'max');
    expect(hlsBitrateFor('Otomatik'), 'no');
    expect(dataSaveWarnAbove('Düşük'), 800);
    expect(dataSaveWarnAbove('Otomatik'), isNull);
  });

  test('ayrıntı puan yıl süre ve tür okur', () {
    final brief = factsFromItem({
      'plot': 'Kisa ozet',
      'genre': 'Dram / Tarih',
      'rating': '8.2',
      'releasedate': '2019-03-01',
      'duration_secs': 7320,
      'director': 'Yonetmen',
      'cast': 'Oyuncu A, Oyuncu B',
      'backdrop_path': ['https://ornek.invalid/arka.jpg'],
    });

    expect(brief.plot, 'Kisa ozet');
    expect(brief.rating, '8.2');
    expect(brief.year, '2019');
    expect(brief.minutes, 122);
    expect(brief.lengthLabel, '122 dk');
    expect(brief.genre, 'Dram / Tarih');
    expect(brief.director, 'Yonetmen');
    expect(brief.cast, 'Oyuncu A, Oyuncu B');
    expect(brief.backdrop, 'https://ornek.invalid/arka.jpg');
    expect(factsFromItem({'rating': '0', 'rating_5based': 4}).rating, '8.0');
  });

  test('geri alma adresi saat ve süreyi taşır', () {
    final url = xtreamTimeshiftUrl(
      xtreamBase('http://ornek.invalid:8080'),
      'uye',
      'gizli',
      42,
      DateTime(2026, 9, 23, 18, 5),
      60,
    );
    final parsed = Uri.parse(url);
    expect(parsed.path, '/streaming/timeshift.php');
    expect(parsed.queryParameters['stream'], '42');
    expect(parsed.queryParameters['duration'], '60');
    expect(parsed.queryParameters['start'], '2026-09-23:18-05');
  });

  test('xmltv programı kanal ve saate bağlar', () {
    const xml = '''
<tv>
<programme start="20260923180000 +0300" stop="20260923190000 +0300" channel="tr.bir">
<title>Akşam</title>
</programme>
</tv>
''';
    final slots = parseXmltv(xml);
    expect(slots.single.channelId, 'tr.bir');
    expect(slots.single.title, 'Akşam');
    expect(parseXmltvTime('20260923180000 +0300'), isNotNull);
  });

  test('portal adayı ve mac biçimi', () {
    expect(normalizeMac('00-1A-79-00-00-01'), '00:1A:79:00:00:01');
    final portals = stalkerPortals('http://ornek.invalid');
    expect(portals.first.path, '/stalker_portal/server/load.php');
  });

  test('m3u rehber kimliğini okur', () {
    const body = '''
#EXTM3U url-tvg="https://ornek.invalid/rehber.xml"
#EXTINF:-1 tvg-id="tr.bir" tvg-logo="https://ornek.invalid/a.jpg",Bir
https://ornek.invalid/bir.m3u8
''';
    final item = parseM3u(body, sourceId: 'kaynak').single;
    expect(item.epgId, 'tr.bir');
    expect(item.guideUrl, 'https://ornek.invalid/rehber.xml');
  });
}
