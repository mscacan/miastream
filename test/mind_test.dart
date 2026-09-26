import 'package:flutter_test/flutter_test.dart';
import 'package:miastream/features/assist/library_mind.dart';
import 'package:miastream/features/browse/catalog_rails.dart';
import 'package:miastream/features/browse/language_page.dart';
import 'package:miastream/features/playback/media_entry.dart';
import 'package:miastream/features/shell/shell_section.dart';

MediaEntry _entry({
  required String id,
  required String title,
  ShellSection section = ShellSection.movies,
  String? genre,
  String? director,
  String? cast,
  int? minutes,
  String? rating,
  String? group,
  String? year,
}) {
  return MediaEntry(
    id: id,
    title: title,
    section: section,
    sourceId: 'kaynak',
    group: group ?? 'Kayıtlar',
    genre: genre,
    director: director,
    cast: cast,
    minutes: minutes,
    rating: rating,
    year: year,
  );
}

void main() {
  test('söz perde ve ses komutuna döner', () {
    expect(parseCommand('sesi kıs'), PlayCommand.quieter);
    expect(parseCommand('perdeyi kapat'), PlayCommand.curtain);
    expect(parseCommand('sonraki bölüm'), PlayCommand.next);
    expect(parseCommand('jenerik burası'), PlayCommand.intro);
    expect(parseCommand('merhaba'), isNull);
  });

  test('tek cümle uzun özeti keser', () {
    expect(oneBreath('Kısa cümle. Devamı var.'), 'Kısa cümle.');
    expect(oneBreath('   '), isNull);
  });

  test('akrabalık yönetmen ve türden gelir', () {
    final focus = _entry(
      id: 'a',
      title: 'Ada',
      genre: 'Dram Tarih',
      director: 'Miran Asmin',
      cast: 'Deniz',
    );
    final close = _entry(
      id: 'b',
      title: 'Kıyı',
      genre: 'Dram',
      director: 'Miran Asmin',
      cast: 'Deniz',
    );
    final far = _entry(id: 'c', title: 'Başka', genre: 'Komedi');
    expect(kinship(focus, close) > kinship(focus, far), isTrue);
  });

  test('bu akşam favoriyi öne alır', () {
    final quiet = _entry(id: 'q', title: 'Sakin', minutes: 90);
    final loved = _entry(id: 'f', title: 'Sevilen', minutes: 100, rating: '8.0');
    final pick = tonightPick([quiet, loved], {'f'}, DateTime(2026, 1, 2));
    expect(pick?.id, 'f');
  });

  test('bot dizi puan ve türü süzer', () {
    final comedy = _entry(id: '1', title: 'Gülüş', genre: 'Komedi', minutes: 100, rating: '6.1');
    final drama = _entry(
      id: '2',
      title: 'Gece',
      section: ShellSection.series,
      genre: 'Dram',
      minutes: 50,
      rating: '8.4',
    );
    final low = _entry(
      id: '3',
      title: 'Soluk',
      section: ShellSection.series,
      genre: 'Dram',
      minutes: 40,
      rating: '5.0',
    );
    final found = botMatches(
      [comedy, drama, low],
      const BotAsk(kind: BotKind.series, minRating: 7, genre: 'dram'),
    );
    expect(found.single.id, '2');
  });

  test('bu kim oyuncu listesini okur', () {
    expect(whoAnswers('bu kim', cast: 'Deniz, Ege'), 'Deniz, Ege');
    expect(whoAnswers('yönetmen kim', director: 'Miran'), 'Miran');
  });

  test('katalog ses süzgeci bilinmeyeni tutar', () {
    final dub = _entry(id: '1', title: 'Türkçe dublaj film');
    final original = _entry(id: '2', title: 'Orijinal ses');
    final plain = _entry(id: '3', title: 'Sade');
    expect(catalogKeeps(dub, 'dub'), isTrue);
    expect(catalogKeeps(original, 'dub'), isFalse);
    expect(catalogKeeps(plain, 'original'), isTrue);
    expect(catalogKeeps(dub, 'either'), isTrue);
  });

  test('türkçe dublaj öne çıkar arapça geriye düşer', () {
    final mixed = featuredMix([
      _entry(id: 'ar', title: 'ليل', section: ShellSection.movies, rating: '9.5'),
      _entry(id: 'en', title: 'Night', section: ShellSection.movies, rating: '8'),
      _entry(id: 'tr', title: 'Gece', group: 'Türkçe Dublaj', section: ShellSection.movies, rating: '6'),
    ]);
    expect(mixed.map((entry) => entry.id).toList(), ['tr', 'en', 'ar']);
    final spot = spotlight([
      _entry(id: 'ar', title: 'Arapça gece', section: ShellSection.movies, rating: '9'),
      _entry(id: 'tr', title: 'Gündüz', group: 'Dublaj', section: ShellSection.movies, rating: '7'),
    ], ShellSection.movies);
    expect(spot.first.id, 'tr');
  });

  test('öne çıkanlar film dizi ve canlıyı karıştırır', () {
    final mixed = featuredMix([
      _entry(id: 'f', title: 'Film', section: ShellSection.movies, rating: '9'),
      _entry(id: 'd', title: 'Dizi', section: ShellSection.series, rating: '8'),
      _entry(id: 'c', title: 'Canli', section: ShellSection.live),
    ]);
    expect(mixed.map((entry) => entry.id).toList(), ['f', 'd', 'c']);
  });

  test('biten kayıt öneriden düşer', () {
    expect(creditFinished(1000, 120 * 60000), isFalse);
    expect(creditFinished(110 * 60000, 120 * 60000), isTrue);
    expect(creditFinished(9 * 60000, 10 * 60000), isTrue);
    final mixed = featuredMix([
      _entry(id: 'f', title: 'Film', section: ShellSection.movies, rating: '9'),
      _entry(id: 'd', title: 'Dizi', section: ShellSection.series, rating: '8'),
    ], skip: {'f'});
    expect(mixed.map((entry) => entry.id).toList(), ['d']);
    final recent = [_entry(id: 'seed', title: 'Tohum', genre: 'Dram')];
    final next = becauseYouWatched(
      [
        _entry(id: 'seed', title: 'Tohum', genre: 'Dram'),
        _entry(id: 'seen', title: 'Biten', genre: 'Dram'),
        _entry(id: 'open', title: 'Açık', genre: 'Dram'),
      ],
      recent,
      skip: {'seen'},
    );
    expect(next.map((entry) => entry.id), isNot(contains('seen')));
    expect(next.map((entry) => entry.id), contains('open'));
  });

  test('kategoriler birbirine karışmaz', () {
    final rails = smartRails([
      for (var i = 0; i < 10; i++)
        _entry(id: 'z$i', title: 'Zirve $i', genre: 'Drama', rating: '${9 - i * 0.05}', minutes: 130),
      for (var i = 0; i < 4; i++)
        _entry(id: 'd$i', title: 'Dram $i', genre: 'Drama', rating: '5.1', minutes: 130),
      for (var i = 0; i < 6; i++)
        _entry(id: 'k$i', title: 'Güldürü $i', genre: 'Komedi', rating: '6.0', minutes: 140),
      for (var i = 0; i < 4; i++)
        _entry(id: 't$i', title: 'Ses $i Dublaj', genre: 'Müzik', rating: '5.5', minutes: 110),
      for (var i = 0; i < 4; i++)
        _entry(id: 'o$i', title: 'Yabancı $i Altyazılı', genre: 'Müzik', rating: '5.4', minutes: 110),
    ]);
    final titles = rails.map((rail) => rail.title).toList();
    expect(titles, contains('Komedi filmleri'));
    expect(titles, contains('Drama filmleri'));
    expect(titles, contains('Türkçe dublaj'));
    expect(titles, contains('Orijinal dilinde'));
    expect(titles, isNot(contains('Belgeseller')));

    final seen = <String>{};
    for (final rail in rails) {
      for (final entry in rail.entries) {
        expect(seen.add(entry.id), isTrue, reason: '${entry.id} birden fazla satırda');
      }
    }
    final comedy = rails.firstWhere((rail) => rail.title == 'Komedi filmleri');
    expect(comedy.entries.every((entry) => entry.id.startsWith('k')), isTrue);
    final dub = rails.firstWhere((rail) => rail.title == 'Türkçe dublaj');
    expect(dub.entries.every((entry) => entry.id.startsWith('t')), isTrue);
  });

  test('dil gözat dizi film ses ve dili ayırır', () {
    expect(
      browseKeeps(
        _entry(id: 'td', title: 'Gece', group: 'TR Dublaj'),
        movies: true,
        series: false,
        voice: BrowseVoice.dub,
        language: 'Türkçe',
      ),
      isTrue,
    );
    expect(
      browseKeeps(
        _entry(id: 'en', title: 'Night', group: 'EN Altyazılı', section: ShellSection.series),
        movies: false,
        series: true,
        voice: BrowseVoice.subtitle,
        language: 'English',
      ),
      isTrue,
    );
    expect(
      browseKeeps(
        _entry(id: 'or', title: 'Night', group: 'EN'),
        movies: true,
        series: false,
        voice: BrowseVoice.original,
        language: 'English',
      ),
      isTrue,
    );
    expect(
      browseKeeps(
        _entry(id: 'td', title: 'Gece', group: 'TR Dublaj', section: ShellSection.series),
        movies: true,
        series: false,
        voice: BrowseVoice.dub,
        language: 'Türkçe',
      ),
      isFalse,
    );
  });
}
