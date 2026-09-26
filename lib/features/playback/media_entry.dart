import '../shell/shell_section.dart';

/// Listeden okunan tek kayıt.
class MediaEntry {
  const MediaEntry({
    required this.id,
    required this.title,
    required this.section,
    required this.sourceId,
    this.url,
    this.seriesId,
    this.group = 'Kayıtlar',
    this.artwork,
    this.streamId,
    this.plot,
    this.genre,
    this.year,
    this.minutes,
    this.rating,
    this.director,
    this.cast,
    this.backdrop,
    this.epgId,
    this.guideUrl,
    this.archiveHours,
    this.playCmd,
    this.linkKind,
  });

  final String id;
  final String title;
  final ShellSection section;
  final String sourceId;
  final String? url;
  final int? seriesId;
  final String group;
  final String? artwork;
  final int? streamId;
  final String? plot;
  final String? genre;
  final String? year;
  final int? minutes;
  final String? rating;
  final String? director;
  final String? cast;
  final String? backdrop;
  final String? epgId;
  final String? guideUrl;
  final int? archiveHours;
  final String? playCmd;
  final String? linkKind;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'section': section.name,
      'sourceId': sourceId,
      'group': group,
      if (url != null) 'url': url,
      if (seriesId != null) 'seriesId': seriesId,
      if (artwork != null) 'artwork': artwork,
      if (streamId != null) 'streamId': streamId,
      if (plot != null) 'plot': plot,
      if (genre != null) 'genre': genre,
      if (year != null) 'year': year,
      if (minutes != null) 'minutes': minutes,
      if (rating != null) 'rating': rating,
      if (director != null) 'director': director,
      if (cast != null) 'cast': cast,
      if (backdrop != null) 'backdrop': backdrop,
      if (epgId != null) 'epgId': epgId,
      if (guideUrl != null) 'guideUrl': guideUrl,
      if (archiveHours != null) 'archiveHours': archiveHours,
      if (playCmd != null) 'playCmd': playCmd,
      if (linkKind != null) 'linkKind': linkKind,
    };
  }

  PlaybackCue toCue() {
    return PlaybackCue(
      id: id,
      title: title,
      url: url ?? playCmd ?? '',
      artwork: artwork,
      sourceId: sourceId,
      streamId: streamId,
      archiveHours: archiveHours,
      playCmd: playCmd,
      linkKind: linkKind,
    );
  }
}

MediaEntry? mediaEntryFrom(Map item) {
  final sectionName = item['section']?.toString();
  final section = ShellSection.values.where((value) => value.name == sectionName).firstOrNull;
  final id = item['id']?.toString() ?? '';
  final title = item['title']?.toString() ?? '';
  final sourceId = item['sourceId']?.toString() ?? '';
  if (section == null || id.isEmpty || title.isEmpty || sourceId.isEmpty) {
    return null;
  }
  return MediaEntry(
    id: id,
    title: title,
    section: section,
    sourceId: sourceId,
    url: item['url']?.toString(),
    seriesId: item['seriesId'] is num ? (item['seriesId'] as num).toInt() : null,
    group: item['group']?.toString() ?? 'Kayıtlar',
    artwork: item['artwork']?.toString(),
    streamId: item['streamId'] is num ? (item['streamId'] as num).toInt() : null,
    plot: item['plot']?.toString(),
    genre: item['genre']?.toString(),
    year: item['year']?.toString(),
    minutes: item['minutes'] is num ? (item['minutes'] as num).toInt() : null,
    rating: item['rating']?.toString(),
    director: item['director']?.toString(),
    cast: item['cast']?.toString(),
    backdrop: item['backdrop']?.toString(),
    epgId: item['epgId']?.toString(),
    guideUrl: item['guideUrl']?.toString(),
    archiveHours: item['archiveHours'] is num ? (item['archiveHours'] as num).toInt() : null,
    playCmd: item['playCmd']?.toString(),
    linkKind: item['linkKind']?.toString(),
  );
}

class Episode {
  const Episode({
    required this.title,
    required this.url,
    this.season,
    this.number,
    this.artwork,
  });

  final String title;
  final String url;
  final int? season;
  final int? number;
  final String? artwork;
}

class PlaybackCue {
  const PlaybackCue({
    required this.title,
    required this.url,
    this.id,
    this.artwork,
    this.seriesTitle,
    this.season,
    this.number,
    this.sourceId,
    this.streamId,
    this.archiveHours,
    this.playCmd,
    this.linkKind,
  });

  final String title;
  final String url;
  final String? id;
  final String? artwork;
  final String? seriesTitle;
  final int? season;
  final int? number;
  final String? sourceId;
  final int? streamId;
  final int? archiveHours;
  final String? playCmd;
  final String? linkKind;

  /// Dizi bölümü kendi yerini tutar. Filmde kayıt kimliği aynı kalır.
  String? get spotId {
    if (id == null) {
      return null;
    }
    if (season == null && number == null) {
      return id;
    }
    return '$id|${season ?? 0}|${number ?? 0}';
  }

  String get headline {
    final series = seriesTitle?.trim();
    if (series == null || series.isEmpty) {
      return title;
    }
    return series;
  }

  String? get detail {
    final series = seriesTitle?.trim();
    if (series == null || series.isEmpty) {
      return null;
    }
    final bits = <String>[];
    if (season != null) {
      bits.add('Sezon $season');
    }
    if (number != null) {
      bits.add('Bölüm $number');
    }
    final name = title.trim();
    if (name.isNotEmpty && name != series) {
      bits.add(name);
    }
    if (bits.isEmpty) {
      return null;
    }
    return bits.join(' · ');
  }
}

class SourceLoadException implements Exception {
  SourceLoadException(this.message);

  final String message;
}
