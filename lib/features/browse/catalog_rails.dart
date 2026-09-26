import '../assist/library_mind.dart';
import '../playback/media_entry.dart';
import '../shell/shell_section.dart';

class CatalogRail {
  const CatalogRail(this.title, this.entries, {this.ranked = false});

  final String title;
  final List<MediaEntry> entries;
  final bool ranked;
}

/// Her kayıt tek satıra gider. Satır; tür, puan, süre ve dile göre listenin tamamından derlenir.
List<CatalogRail> smartRails(List<MediaEntry> entries, {List<MediaEntry> watched = const []}) {
  if (entries.isEmpty) {
    return const [];
  }
  final series = entries.first.section == ShellSection.series;
  final facts = [for (final entry in entries) _Fact(entry)];
  final taken = <String>{};
  final rails = <CatalogRail>[];

  void add(String title, List<_Fact> picked, {bool ranked = false, int cap = 18}) {
    if (picked.length < 4) {
      return;
    }
    final chosen = picked.length > cap ? picked.sublist(0, cap) : picked;
    for (final fact in chosen) {
      taken.add(fact.entry.id);
    }
    rails.add(CatalogRail(title, [for (final fact in chosen) fact.entry], ranked: ranked));
  }

  List<_Fact> claim(bool Function(_Fact fact) test, {int cap = 18, bool byRating = true}) {
    final hit = [for (final fact in facts) if (!taken.contains(fact.entry.id) && test(fact)) fact];
    hit.sort((a, b) {
      if (!byRating) {
        return a.entry.title.compareTo(b.entry.title);
      }
      final byOffer = offerValue(b.entry).compareTo(offerValue(a.entry));
      if (byOffer != 0) {
        return byOffer;
      }
      return a.entry.title.compareTo(b.entry.title);
    });
    return hit.length > cap ? hit.sublist(0, cap) : hit;
  }

  final watchedIds = {for (final entry in watched) entry.id};
  add('Bugünün Top 10', claim((fact) => fact.rating != null, cap: 10), ranked: true, cap: 10);

  const moods = <(String, List<String>)>[
    ('Korku', ['korku', 'horror']),
    ('Belgesel', ['belgesel', 'documentary']),
    ('Bilim kurgu', ['bilim kurgu', 'bilimkurgu', 'sci-fi', 'science fiction', 'fantastik', 'fantasy']),
    ('Komedi', ['komedi', 'comedy', 'komik']),
    ('Suç', ['suç', 'crime', 'gangster', 'mafya']),
    ('Gerilim', ['gerilim', 'thriller']),
    ('Aksiyon ve macera', ['aksiyon', 'action', 'macera', 'adventure']),
    ('Aile', ['aile', 'family']),
    ('Duygusal', ['duygusal', 'romantik', 'romance', 'melodram']),
    ('Uçuk kaçık', ['absürt', 'absurd', 'uçuk', 'parodi', 'parody']),
    ('Şiddet içerikli', ['şiddet', 'violence']),
    ('Drama', ['dram', 'drama']),
  ];
  if (!series) {
    add(
      'Arkadaşlar gecesi',
      claim(
        (fact) => fact.kind == 'Komedi' && fact.minutes != null && fact.minutes! >= 80 && fact.minutes! <= 120,
      ),
    );
  }
  for (final mood in moods) {
    final label = switch (mood.$1) {
      'Belgesel' => series ? 'Belgesel diziler' : 'Belgeseller',
      'Suç' => series ? 'Suç dizileri' : 'Suç drama filmleri',
      'Uçuk kaçık' => series ? 'Uçuk kaçık diziler' : 'Uçuk kaçık filmler',
      _ => series ? '${mood.$1} dizileri' : '${mood.$1} filmleri',
    };
    add(label, claim((fact) => fact.kind == mood.$1));
  }

  add(
    series ? 'Yerli diziler' : 'Yerli filmler',
    claim((fact) => fact.yerli),
  );
  add(
    'Türkçe dublaj',
    claim((fact) => fact.voice == _Voice.dub),
  );
  add(
    'Orijinal dilinde',
    claim((fact) => fact.voice == _Voice.original),
  );
  add(
    series ? '90 dakikalık bölümler' : '90 dakikalık filmler',
    claim((fact) => fact.minutes != null && fact.minutes! >= 80 && fact.minutes! <= 100),
  );
  add(
    'Gerçek hayattan uyarlanan ${series ? 'diziler' : 'filmler'}',
    claim((fact) => fact.trueStory),
  );
  add(
    series ? 'Ödüllü diziler' : 'Ödüllü filmler',
    claim((fact) => fact.awarded),
  );
  add(
    series ? 'Eleştirmenlerden tam not alan diziler' : 'Eleştirmenlerden tam not alan filmler',
    claim((fact) => fact.rating != null && fact.rating! >= 8),
  );
  add(
    'Herkes tarafından çok sevilenler',
    claim((fact) => fact.rating != null && fact.rating! >= 6.5 && fact.rating! < 8),
  );
  add(
    series ? 'Gişe rekortmeni diziler' : 'Gişe rekortmeni filmler',
    claim(
      (fact) => fact.rating != null && fact.rating! >= 7 && fact.year != null && fact.year! >= DateTime.now().year - 6,
    ),
  );
  final forYou = _forYou(facts, watchedIds, taken);
  if (forYou.length >= 4) {
    final chosen = forYou.length > 18 ? forYou.sublist(0, 18) : forYou;
    for (final fact in chosen) {
      taken.add(fact.entry.id);
    }
    final rail = CatalogRail('Bugün senin için seçtiklerimiz', [for (final fact in chosen) fact.entry]);
    final topAt = rails.indexWhere((item) => item.title == 'Bugünün Top 10');
    rails.insert(topAt < 0 ? 0 : topAt + 1, rail);
  }
  return rails;
}

List<_Fact> _forYou(List<_Fact> facts, Set<String> watchedIds, Set<String> taken) {
  final taste = <String>{};
  for (final fact in facts) {
    if (watchedIds.contains(fact.entry.id) && fact.kind != null) {
      taste.add(fact.kind!);
    }
  }
  final pool = [
    for (final fact in facts)
      if (!taken.contains(fact.entry.id) && !watchedIds.contains(fact.entry.id)) fact,
  ];
  pool.sort((a, b) {
    final scoreA = offerValue(a.entry) + (taste.contains(a.kind) ? 5 : 0);
    final scoreB = offerValue(b.entry) + (taste.contains(b.kind) ? 5 : 0);
    return scoreB.compareTo(scoreA);
  });
  if (pool.length < 4) {
    return const [];
  }
  final day = DateTime.now().difference(DateTime(2026)).inDays.abs() % pool.length;
  final turned = [...pool.skip(day), ...pool.take(day)];
  return turned.length > 18 ? turned.sublist(0, 18) : turned;
}

class _Fact {
  _Fact(this.entry)
    : genreText = '${entry.genre ?? ''} ${entry.group}'.toLowerCase(),
      plotText = '${entry.plot ?? ''} ${entry.title} ${entry.group}'.toLowerCase(),
      rating = _score(entry.rating),
      minutes = entry.minutes,
      year = _year(entry.year) {
    kind = _kind(genreText);
    yerli = _word(genreText, 'yerli');
    voice = _voice(plotText);
    trueStory = _word(plotText, 'gerçek hayattan') ||
        _word(plotText, 'gerçek olay') ||
        _word(plotText, 'uyarlanan') ||
        plotText.contains('true story') ||
        _word(plotText, 'biyografi');
    awarded = _word(plotText, 'oscar') || _word(plotText, 'ödül') || _word(genreText, 'ödül');
  }

  final MediaEntry entry;
  final String genreText;
  final String plotText;
  final double? rating;
  final int? minutes;
  final int? year;
  late final String? kind;
  late final bool yerli;
  late final _Voice voice;
  late final bool trueStory;
  late final bool awarded;
}

enum _Voice { dub, original, either }

const _moods = <(String, List<String>)>[
  ('Korku', ['korku', 'horror']),
  ('Belgesel', ['belgesel', 'documentary']),
  ('Bilim kurgu', ['bilim kurgu', 'bilimkurgu', 'sci-fi', 'science fiction', 'fantastik', 'fantasy']),
  ('Komedi', ['komedi', 'comedy', 'komik']),
  ('Suç', ['suç', 'crime', 'gangster', 'mafya']),
  ('Gerilim', ['gerilim', 'thriller']),
  ('Aksiyon ve macera', ['aksiyon', 'action', 'macera', 'adventure']),
  ('Aile', ['aile', 'family']),
  ('Duygusal', ['duygusal', 'romantik', 'romance', 'melodram']),
  ('Uçuk kaçık', ['absürt', 'absurd', 'uçuk', 'parodi', 'parody']),
  ('Şiddet içerikli', ['şiddet', 'violence']),
  ('Drama', ['dram', 'drama']),
];

String? _kind(String genreText) {
  for (final mood in _moods) {
    for (final key in mood.$2) {
      if (_word(genreText, key)) {
        return mood.$1;
      }
    }
  }
  return null;
}

_Voice _voice(String text) {
  final dub = _word(text, 'dublaj');
  final original =
      _word(text, 'altyazılı') ||
      _word(text, 'altyazili') ||
      _word(text, 'altyazı') ||
      _word(text, 'orijinal') ||
      _word(text, 'original') ||
      _word(text, 'subtitle');
  if (dub && !original) {
    return _Voice.dub;
  }
  if (original && !dub) {
    return _Voice.original;
  }
  return _Voice.either;
}

bool _word(String text, String key) {
  var start = 0;
  while (start <= text.length - key.length) {
    final found = text.indexOf(key, start);
    if (found < 0) {
      return false;
    }
    final before = found == 0 || !_letter(text.codeUnitAt(found - 1));
    final after = found + key.length == text.length || !_letter(text.codeUnitAt(found + key.length));
    if (before && after) {
      return true;
    }
    start = found + key.length;
  }
  return false;
}

bool _letter(int unit) {
  if (unit >= 97 && unit <= 122) {
    return true;
  }
  const extra = 'çğıöşü';
  return extra.contains(String.fromCharCode(unit));
}

double? _score(String? raw) {
  if (raw == null) {
    return null;
  }
  final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(raw);
  if (match == null) {
    return null;
  }
  return double.tryParse(match.group(1)!.replaceAll(',', '.'));
}

int? _year(String? raw) {
  if (raw == null) {
    return null;
  }
  final match = RegExp(r'(19|20)\d{2}').firstMatch(raw);
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(0)!);
}
