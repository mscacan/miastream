import '../playback/media_entry.dart';
import '../shell/shell_section.dart';

enum PlayCommand { quieter, louder, mute, next, previous, pause, play, curtain, salon, intro }

PlayCommand? parseCommand(String raw) {
  final text = raw.toLowerCase().trim();
  if (text.isEmpty) {
    return null;
  }
  if (text.contains('perde')) {
    return PlayCommand.curtain;
  }
  if (text.contains('salon')) {
    return PlayCommand.salon;
  }
  if (text.contains('jenerik')) {
    return PlayCommand.intro;
  }
  if (text.contains('sessiz') || text.contains('sustur')) {
    return PlayCommand.mute;
  }
  if (text.contains('kıs') || text.contains('kis') || text.contains('alçalt') || text.contains('alcalt')) {
    return PlayCommand.quieter;
  }
  if (text.contains('yükselt') || text.contains('yukselt') || text.contains('sesi aç') || text.contains('sesi ac')) {
    return PlayCommand.louder;
  }
  if (text.contains('sonraki')) {
    return PlayCommand.next;
  }
  if (text.contains('önceki') || text.contains('onceki')) {
    return PlayCommand.previous;
  }
  if (text.contains('duraklat') || text.contains('durdur')) {
    return PlayCommand.pause;
  }
  if (text.contains('oynat') || text.contains('devam')) {
    return PlayCommand.play;
  }
  return null;
}

String? shortPlot(String? plot) {
  if (plot == null) {
    return null;
  }
  final text = plot.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) {
    return null;
  }
  final sentences = RegExp(r'.+?[.!?]+(?:\s|$)')
      .allMatches(text)
      .map((match) => match.group(0)!.trim())
      .where((line) => line.isNotEmpty)
      .take(2)
      .join(' ');
  final body = sentences.isEmpty ? text : sentences;
  if (body.length <= 180) {
    return body;
  }
  final cut = body.substring(0, 180);
  final space = cut.lastIndexOf(' ');
  final kept = space > 60 ? cut.substring(0, space) : cut;
  return '${kept.trim()}…';
}

List<MediaEntry> spotlight(List<MediaEntry> entries, ShellSection section, {int count = 5, int shift = 0}) {
  final rows = [for (final entry in entries) if (entry.section == section) entry];
  if (rows.isEmpty) {
    return const [];
  }
  final ranked = rows.asMap().entries.toList();
  ranked.sort((a, b) {
    final byScore = _freshScore(b, rows.length).compareTo(_freshScore(a, rows.length));
    if (byScore != 0) {
      return byScore;
    }
    return b.key.compareTo(a.key);
  });
  final pool = [for (final item in ranked.take(24)) item.value];
  if (pool.length <= count) {
    return pool;
  }
  final turn = shift.abs() % pool.length;
  final turned = [...pool.sublist(turn), ...pool.sublist(0, turn)];
  return turned.take(count).toList();
}

double _freshScore(MapEntry<int, MediaEntry> item, int total) {
  final fresh = total <= 1 ? 1.0 : item.key / (total - 1);
  return offerValue(item.value) * 2 + fresh * 8;
}

String? oneBreath(String? plot) {
  if (plot == null) {
    return null;
  }
  final text = plot.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) {
    return null;
  }
  final match = RegExp(r'^(.+?[.!?])(?:\s|$)').firstMatch(text);
  final sentence = (match?.group(1) ?? text).trim();
  if (sentence.length <= 140) {
    return sentence;
  }
  final cut = sentence.substring(0, 140);
  final space = cut.lastIndexOf(' ');
  final kept = space > 40 ? cut.substring(0, space) : cut;
  return '${kept.trim()}…';
}

int kinship(MediaEntry focus, MediaEntry other) {
  if (focus.id == other.id) {
    return 0;
  }
  var score = 0;
  final group = focus.group.trim();
  if (group.isNotEmpty && group == other.group && group != 'Filmler' && group != 'Diziler' && group != 'Kayıtlar') {
    score += 1;
  }
  score += _share(focus.genre, other.genre) * 3;
  score += _share(focus.director, other.director) * 4;
  score += _share(focus.cast, other.cast) * 2;
  return score;
}

MediaEntry? tonightPick(List<MediaEntry> entries, Set<String> favorites, DateTime now) {
  if (entries.isEmpty) {
    return null;
  }
  int score(MediaEntry entry) {
    var value = 0;
    if (favorites.contains(entry.id)) {
      value += 5;
    }
    final minutes = entry.minutes;
    if (minutes != null && minutes >= 40 && minutes <= 140) {
      value += 3;
    }
    if (entry.rating != null) {
      value += 1;
    }
    return value;
  }

  final ranked = [...entries]..sort((a, b) {
    final byScore = score(b).compareTo(score(a));
    if (byScore != 0) {
      return byScore;
    }
    return a.title.compareTo(b.title);
  });
  final best = score(ranked.first);
  final window = ranked.where((entry) => score(entry) == best).toList();
  final day = now.difference(DateTime(now.year)).inDays;
  return window[day % window.length];
}

List<MediaEntry> featuredMix(List<MediaEntry> entries, {int limit = 18, Set<String> skip = const {}}) {
  final open = [for (final entry in entries) if (!skip.contains(entry.id)) entry];
  List<MediaEntry> column(ShellSection section) {
    final rows = [for (final entry in open) if (entry.section == section) entry];
    rows.sort(compareOffer);
    return rows;
  }

  final columns = [
    column(ShellSection.movies),
    column(ShellSection.series),
    column(ShellSection.live),
  ];
  final mixed = <MediaEntry>[];
  var index = 0;
  while (mixed.length < limit && columns.any((rows) => index < rows.length)) {
    for (final rows in columns) {
      if (index < rows.length && mixed.length < limit) {
        mixed.add(rows[index]);
      }
    }
    index++;
  }
  return mixed;
}

List<MediaEntry> becauseYouWatched(
  List<MediaEntry> entries,
  List<MediaEntry> recent, {
  int limit = 18,
  Set<String> skip = const {},
}) {
  if (recent.isEmpty) {
    return const [];
  }
  final seeds = recent.take(4).toList();
  final seen = {for (final entry in recent) entry.id, ...skip};
  final scored = <(int, MediaEntry)>[];
  for (final entry in entries) {
    if (seen.contains(entry.id)) {
      continue;
    }
    if (entry.section != ShellSection.movies &&
        entry.section != ShellSection.series &&
        entry.section != ShellSection.live) {
      continue;
    }
    var score = 0;
    if (readsArabic(entry)) {
      score -= 6;
    } else if (_voiceHint(entry) == BotVoice.dub) {
      score += 2;
    }
    for (final seed in seeds) {
      score += kinship(seed, entry);
      if (seed.section == entry.section) {
        score += 1;
      }
      if (seed.group == entry.group && seed.group != 'Kayıtlar' && seed.group != 'Filmler' && seed.group != 'Diziler') {
        score += 1;
      }
    }
    if (score > 0) {
      scored.add((score, entry));
    }
  }
  scored.sort((a, b) {
    final byScore = b.$1.compareTo(a.$1);
    if (byScore != 0) {
      return byScore;
    }
    return a.$2.title.compareTo(b.$2.title);
  });
  if (scored.isEmpty) {
    final sections = seeds.map((entry) => entry.section).toSet();
    return [
      for (final entry in entries)
        if (!seen.contains(entry.id) && sections.contains(entry.section)) entry,
    ].take(limit).toList();
  }
  return [for (final item in scored.take(limit)) item.$2];
}

bool creditFinished(int ms, int totalMs) {
  if (ms <= 8000 || totalMs < 60000) {
    return false;
  }
  final minutes = totalMs ~/ 60000;
  if (minutes >= 15) {
    return totalMs - ms <= 10 * 60 * 1000;
  }
  return ms >= (totalMs * 0.85).round();
}

String? whoAnswers(String question, {String? cast, String? director}) {
  final text = question.toLowerCase();
  if (text.contains('yönet') || text.contains('yonet')) {
    if (director == null || director.trim().isEmpty) {
      return 'Bu kayıtta yönetmen yazmıyor.';
    }
    return director.trim();
  }
  if (text.contains('kim') || text.contains('oyuncu')) {
    if (cast == null || cast.trim().isEmpty) {
      return 'Bu kayıtta oyuncu yazmıyor.';
    }
    return cast.trim();
  }
  return null;
}

int _share(String? left, String? right) {
  final a = _tokens(left);
  final b = _tokens(right);
  if (a.isEmpty || b.isEmpty) {
    return 0;
  }
  return a.intersection(b).length;
}

enum BotKind { either, series, movie }

enum BotVoice { either, dub, original }

enum BotSpan { either, short, medium, long }

class BotAsk {
  const BotAsk({
    this.kind = BotKind.either,
    this.minRating,
    this.voice = BotVoice.either,
    this.genre,
    this.span = BotSpan.either,
  });

  final BotKind kind;
  final double? minRating;
  final BotVoice voice;
  final String? genre;
  final BotSpan span;
}

List<MediaEntry> botMatches(List<MediaEntry> entries, BotAsk ask) {
  final pool = [
    for (final entry in entries)
      if (entry.section == ShellSection.movies || entry.section == ShellSection.series) entry,
  ];
  final ranked = <(int, MediaEntry)>[];
  for (final entry in pool) {
    if (ask.kind == BotKind.series && entry.section != ShellSection.series) {
      continue;
    }
    if (ask.kind == BotKind.movie && entry.section != ShellSection.movies) {
      continue;
    }
    final rating = _rating(entry.rating);
    if (ask.minRating != null && rating != null && rating < ask.minRating!) {
      continue;
    }
    final minutes = entry.minutes;
    if (!_fitsSpan(minutes, ask.span)) {
      continue;
    }
    final voice = _voiceHint(entry);
    if (ask.voice == BotVoice.dub && voice == BotVoice.original) {
      continue;
    }
    if (ask.voice == BotVoice.original && voice == BotVoice.dub) {
      continue;
    }
    var score = 1;
    if (ask.kind != BotKind.either && (ask.kind == BotKind.series) == (entry.section == ShellSection.series)) {
      score += 3;
    }
    if (ask.minRating != null && rating != null) {
      score += 3;
    }
    if (ask.genre != null && _tokens('${entry.genre} ${entry.group} ${entry.title}').contains(ask.genre)) {
      score += 4;
    }
    if (ask.voice != BotVoice.either && voice == ask.voice) {
      score += 2;
    }
    if (ask.span != BotSpan.either && minutes != null) {
      score += 2;
    }
    ranked.add((score, entry));
  }
  ranked.sort((a, b) {
    final byScore = b.$1.compareTo(a.$1);
    if (byScore != 0) {
      return byScore;
    }
    return a.$2.title.compareTo(b.$2.title);
  });
  if (ranked.length <= 12) {
    return [for (final item in ranked) item.$2];
  }
  return [for (final item in ranked.take(12)) item.$2];
}

/// Türkçe dublaj puanı yükseltir, Arapça kayıtlar öneride geriye düşer.
double offerValue(MediaEntry entry) {
  final rating = _rating(entry.rating) ?? 0;
  if (entry.section == ShellSection.live) {
    return rating;
  }
  if (readsArabic(entry)) {
    return rating - 8;
  }
  if (_voiceHint(entry) == BotVoice.dub) {
    return rating + 3;
  }
  return rating;
}

bool readsArabic(MediaEntry entry) {
  final text = '${entry.title} ${entry.group} ${entry.genre ?? ''}';
  if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) {
    return true;
  }
  final lower = text.toLowerCase();
  return lower.contains('arapça') || lower.contains('arapca') || lower.contains('arabic');
}

int compareOffer(MediaEntry a, MediaEntry b) {
  final byOffer = offerValue(b).compareTo(offerValue(a));
  if (byOffer != 0) {
    return byOffer;
  }
  return a.title.compareTo(b.title);
}

List<MediaEntry> offeredTitles(List<MediaEntry> entries) {
  final rows = [...entries]..sort(compareOffer);
  return rows;
}

double? _rating(String? raw) {
  if (raw == null) {
    return null;
  }
  final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(raw);
  if (match == null) {
    return null;
  }
  return double.tryParse(match.group(1)!.replaceAll(',', '.'));
}

bool _fitsSpan(int? minutes, BotSpan span) {
  if (span == BotSpan.either || minutes == null || minutes <= 0) {
    return true;
  }
  return switch (span) {
    BotSpan.short => minutes <= 50,
    BotSpan.medium => minutes >= 50 && minutes <= 110,
    BotSpan.long => minutes >= 110,
    BotSpan.either => true,
  };
}

String? voiceLabel(MediaEntry entry) {
  return switch (_voiceHint(entry)) {
    BotVoice.dub => 'Türkçe dublaj',
    BotVoice.original => 'Orijinal ses',
    BotVoice.either => null,
  };
}

bool catalogKeeps(MediaEntry entry, String voice) {
  if (voice != 'dub' && voice != 'original') {
    return true;
  }
  final hint = _voiceHint(entry);
  if (voice == 'dub') {
    return hint != BotVoice.original;
  }
  return hint != BotVoice.dub;
}

BotVoice _voiceHint(MediaEntry entry) {
  final text = '${entry.title} ${entry.group} ${entry.genre ?? ''}'.toLowerCase();
  final dub = text.contains('dublaj') || text.contains('türkçe') || text.contains('turkce');
  final original = text.contains('altyaz') || text.contains('orijinal') || text.contains('original');
  if (dub && !original) {
    return BotVoice.dub;
  }
  if (original && !dub) {
    return BotVoice.original;
  }
  return BotVoice.either;
}

Set<String> _tokens(String? raw) {
  if (raw == null) {
    return {};
  }
  return raw
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9çğıöşü]+'))
      .where((token) => token.length > 2)
      .toSet();
}
