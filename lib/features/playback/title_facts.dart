import 'artwork.dart';
import 'media_entry.dart';

class TitleBrief {
  const TitleBrief({
    this.plot,
    this.genre,
    this.year,
    this.minutes,
    this.rating,
    this.director,
    this.cast,
    this.backdrop,
    this.episodes = const [],
  });

  final String? plot;
  final String? genre;
  final String? year;
  final int? minutes;
  final String? rating;
  final String? director;
  final String? cast;
  final String? backdrop;
  final List<Episode> episodes;

  String? get lengthLabel {
    final value = minutes;
    if (value == null || value <= 0) {
      return null;
    }
    return '$value dk';
  }

  TitleBrief fillFrom(MediaEntry entry) {
    return TitleBrief(
      plot: plot ?? entry.plot,
      genre: genre ?? entry.genre,
      year: year ?? entry.year,
      minutes: minutes ?? entry.minutes,
      rating: rating ?? entry.rating,
      director: director ?? entry.director,
      cast: cast ?? entry.cast,
      backdrop: backdrop ?? entry.backdrop ?? entry.artwork,
      episodes: episodes,
    );
  }
}

TitleBrief factsFromItem(Map item, {Uri? base}) {
  return TitleBrief(
    plot: _text(item, const ['plot', 'description', 'overview']),
    genre: _text(item, const ['genre']),
    year: _year(item),
    minutes: _minutes(item),
    rating: _rating(item),
    director: _text(item, const ['director']),
    cast: _text(item, const ['cast', 'actors', 'actor']),
    backdrop: _backdrop(item, base),
  );
}

String? _text(Map item, List<String> keys) {
  for (final key in keys) {
    final value = item[key]?.toString().trim() ?? '';
    final lower = value.toLowerCase();
    if (value.isEmpty || lower == 'null' || lower == 'n/a' || value == '0') {
      continue;
    }
    return value;
  }
  return null;
}

String? _year(Map item) {
  final direct = RegExp(r'(?:19|20)\d{2}').firstMatch('${item['year'] ?? ''}');
  if (direct != null) {
    return direct.group(0);
  }
  for (final key in const ['releasedate', 'releaseDate', 'release_date']) {
    final found = RegExp(r'(?:19|20)\d{2}').firstMatch('${item[key] ?? ''}');
    if (found != null) {
      return found.group(0);
    }
  }
  return null;
}

int? _minutes(Map item) {
  final seconds = int.tryParse('${item['duration_secs'] ?? ''}');
  if (seconds != null && seconds > 0) {
    return (seconds / 60).round();
  }
  final run = int.tryParse('${item['episode_run_time'] ?? ''}');
  if (run != null && run > 0 && run < 1000) {
    return run;
  }
  final raw = '${item['duration'] ?? ''}'.trim();
  final clock = RegExp(r'^(\d+):(\d+):(\d+)$').firstMatch(raw);
  if (clock != null) {
    final hours = int.parse(clock.group(1)!);
    final minutes = int.parse(clock.group(2)!);
    final total = hours * 60 + minutes;
    return total > 0 ? total : null;
  }
  final digits = RegExp(r'^(\d{1,3})').firstMatch(raw);
  if (digits == null) {
    return null;
  }
  final minutes = int.parse(digits.group(1)!);
  return minutes > 0 ? minutes : null;
}

String? _rating(Map item) {
  final raw = _number(item['rating']);
  final five = _number(item['rating_5based']);
  var score = raw;
  if ((score == null || score <= 0) && five != null && five > 0) {
    score = five <= 5 ? five * 2 : five;
  }
  if (score == null || score <= 0 || score > 10) {
    return null;
  }
  return score.toStringAsFixed(1);
}

double? _number(dynamic value) {
  return double.tryParse('$value'.trim().replaceAll(',', '.'));
}

String? _backdrop(Map item, Uri? base) {
  final raw = item['backdrop_path'];
  if (raw is List) {
    for (final piece in raw) {
      final found = httpArtwork(piece, base: base);
      if (found != null) {
        return found;
      }
    }
  }
  return httpArtwork(raw, base: base) ?? artworkFrom(item, base: base);
}
