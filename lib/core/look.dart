import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../features/playback/track_labels.dart';
import '../features/shell/shell_section.dart';
import 'theme.dart';

enum MiaMood { sinema, gece, kum }

/// Oturum içi görünüm ve oynatıcı tercihleri. Kaynak listesi tutmaz.
class MiaLook extends ChangeNotifier {
  MiaMood mood = MiaMood.sinema;
  bool autoplayNext = true;
  bool resumeWatching = true;
  String aspect = 'Otomatik';
  String dataSave = 'Otomatik';
  String subtitleSize = 'Orta';
  bool clock24 = true;
  String openingPage = ShellSection.home.label;
  String audioPrimary = 'Türkçe';
  String audioSecondary = 'English';
  String subtitlePrimary = 'Kapalı';
  String subtitleSecondary = 'Türkçe';
  bool skipSubtitleWhenAudioMatches = true;
  String botKind = 'either';
  double? botMinRating;
  String botVoice = 'either';
  String? botGenre;
  String botSpan = 'either';
  bool botAsked = false;
  String catalogVoice = 'either';
  List<String> homeRails = List.of(defaultHomeRails);
  Color? roomAccent;
  Color? roomGlow;
  var _loaded = false;

  MiaPalette get palette {
    final base = switch (mood) {
      MiaMood.sinema => MiaPalette.sinema,
      MiaMood.gece => MiaPalette.gece,
      MiaMood.kum => MiaPalette.kum,
    };
    final accent = roomAccent;
    if (accent == null) {
      return base;
    }
    return MiaPalette(
      background: base.background,
      surface: base.surface,
      card: base.card,
      accent: accent,
      glow: roomGlow ?? base.glow,
      muted: base.muted,
      line: base.line,
      label: base.label,
    );
  }

  void setRoom(Color accent) {
    roomAccent = accent;
    roomGlow = Color.lerp(accent, Colors.black, 0.45) ?? accent;
    notifyListeners();
  }

  void setMood(MiaMood value) {
    mood = value;
    _touch();
  }

  void setAutoplay(bool value) {
    autoplayNext = value;
    _touch();
  }

  void setResume(bool value) {
    resumeWatching = value;
    _touch();
  }

  void setAspect(String value) {
    aspect = value;
    _touch();
  }

  void setDataSave(String value) {
    dataSave = _one(value, const ['Otomatik', 'Düşük', 'Orta', 'Yüksek'], 'Otomatik');
    _touch();
  }

  void setSubtitleSize(String value) {
    subtitleSize = value;
    _touch();
  }

  void setClock24(bool value) {
    clock24 = value;
    _touch();
  }

  void setOpeningPage(String value) {
    openingPage = value;
    _touch();
  }

  void setAudioPrimary(String value) {
    audioPrimary = value;
    _touch();
  }

  void setAudioSecondary(String value) {
    audioSecondary = value;
    _touch();
  }

  void setSubtitlePrimary(String value) {
    subtitlePrimary = value;
    _touch();
  }

  void setSubtitleSecondary(String value) {
    subtitleSecondary = value;
    _touch();
  }

  void setSkipSubtitle(bool value) {
    skipSubtitleWhenAudioMatches = value;
    _touch();
  }

  void setCatalogVoice(String value) {
    catalogVoice = _one(value, ['either', 'dub', 'original'], 'either');
    _touch();
  }

  void setHomeRails(List<String> ids) {
    final next = <String>[];
    for (final id in ids) {
      if (homeRailIds.contains(id) && !next.contains(id)) {
        next.add(id);
      }
    }
    homeRails = next;
    _touch();
  }

  void setBot({
    required String kind,
    required double? minRating,
    required String voice,
    required String? genre,
    required String span,
    required bool asked,
  }) {
    botKind = _one(kind, ['either', 'series', 'movie'], 'either');
    botMinRating = minRating == 6 || minRating == 7 || minRating == 8 ? minRating : null;
    botVoice = _one(voice, ['either', 'dub', 'original'], 'either');
    botGenre = _oneOrNull(genre, ['dram', 'komedi', 'gerilim', 'aksiyon', 'romantik', 'korku']);
    botSpan = _one(span, ['either', 'short', 'medium', 'long'], 'either');
    botAsked = asked;
    _touch();
  }

  void _touch() {
    notifyListeners();
    _save();
  }

  Future<void> ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    try {
      final file = File('${(await getApplicationSupportDirectory()).path}/gorunum.json');
      if (!file.existsSync()) {
        return;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return;
      }
      final opening = decoded['opening']?.toString();
      if (opening != null && ShellSection.values.any((section) => section.label == opening)) {
        openingPage = opening;
      }
      audioPrimary = _known(decoded['audioPrimary'], spokenLanguages, audioPrimary);
      audioSecondary = _known(decoded['audioSecondary'], spokenLanguages, audioSecondary);
      subtitlePrimary = _known(decoded['subtitlePrimary'], subtitleLanguages, subtitlePrimary);
      subtitleSecondary = _known(decoded['subtitleSecondary'], subtitleLanguages, subtitleSecondary);
      final skip = decoded['skipSubtitleWhenAudioMatches'];
      if (skip is bool) {
        skipSubtitleWhenAudioMatches = skip;
      }
      botKind = _one(decoded['botKind'], ['either', 'series', 'movie'], botKind);
      botVoice = _one(decoded['botVoice'], ['either', 'dub', 'original'], botVoice);
      botSpan = _one(decoded['botSpan'], ['either', 'short', 'medium', 'long'], botSpan);
      botGenre = _oneOrNull(decoded['botGenre'], ['dram', 'komedi', 'gerilim', 'aksiyon', 'romantik', 'korku']);
      final rating = decoded['botMinRating'];
      botMinRating = rating == 6 || rating == 7 || rating == 8 ? (rating as num).toDouble() : null;
      if (decoded['botAsked'] is bool) {
        botAsked = decoded['botAsked'] as bool;
      }
      catalogVoice = _one(decoded['catalogVoice'], ['either', 'dub', 'original'], catalogVoice);
      dataSave = _one(decoded['dataSave'], const ['Otomatik', 'Düşük', 'Orta', 'Yüksek'], dataSave);
      if (decoded.containsKey('homeRails')) {
        homeRails = _withCatalogRails(_rails(decoded['homeRails']));
      }
      final moodName = decoded['mood']?.toString();
      for (final item in MiaMood.values) {
        if (item.name == moodName) {
          mood = item;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final file = File('${(await getApplicationSupportDirectory()).path}/gorunum.json');
      await file.writeAsString(
        jsonEncode({
          'opening': openingPage,
          'audioPrimary': audioPrimary,
          'audioSecondary': audioSecondary,
          'subtitlePrimary': subtitlePrimary,
          'subtitleSecondary': subtitleSecondary,
          'skipSubtitleWhenAudioMatches': skipSubtitleWhenAudioMatches,
          'botKind': botKind,
          'botMinRating': botMinRating,
          'botVoice': botVoice,
          'botGenre': botGenre,
          'botSpan': botSpan,
          'botAsked': botAsked,
          'catalogVoice': catalogVoice,
          'dataSave': dataSave,
          'homeRails': homeRails,
          'mood': mood.name,
        }),
      );
    } catch (_) {}
  }
}

String _one(dynamic raw, List<String> allowed, String fallback) {
  final value = raw?.toString();
  if (value != null && allowed.contains(value)) {
    return value;
  }
  return fallback;
}

String? _oneOrNull(dynamic raw, List<String> allowed) {
  final value = raw?.toString();
  if (value != null && allowed.contains(value)) {
    return value;
  }
  return null;
}

String _known(dynamic raw, List<String> allowed, String fallback) {
  final value = raw?.toString();
  if (value != null && allowed.contains(value)) {
    return value;
  }
  return fallback;
}

const defaultHomeRails = ['featured', 'paused', 'list', 'liked', 'because', 'recent', 'live', 'movies', 'series'];

const _oldHomeRails = ['featured', 'because', 'recent', 'liked', 'paused'];

List<String> _withCatalogRails(List<String> rails) {
  final next = [...rails];
  if (next.length == _oldHomeRails.length && _oldHomeRails.every(next.contains)) {
    next.addAll(['live', 'movies', 'series']);
  }
  if (!next.contains('list')) {
    final at = next.indexOf('paused');
    next.insert(at < 0 ? 0 : at + 1, 'list');
  }
  return next;
}

const homeRailIds = ['featured', 'because', 'recent', 'list', 'liked', 'paused', 'live', 'movies', 'series'];

List<String> _rails(dynamic raw) {
  if (raw is! List) {
    return List.of(defaultHomeRails);
  }
  final next = <String>[];
  for (final item in raw) {
    final id = item?.toString();
    if (id != null && homeRailIds.contains(id) && !next.contains(id)) {
      next.add(id);
    }
  }
  return next;
}

class LookScope extends InheritedNotifier<MiaLook> {
  const LookScope({required MiaLook look, required super.child, super.key})
      : super(notifier: look);

  static MiaLook of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LookScope>();
    assert(scope != null, 'LookScope bulunamadı');
    return scope!.notifier!;
  }
}
