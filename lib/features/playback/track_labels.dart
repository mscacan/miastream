const spokenLanguages = [
  'Türkçe',
  'English',
  'Deutsch',
  'Français',
  'Español',
  'العربية',
  'Русский',
];

const subtitleLanguages = ['Kapalı', ...spokenLanguages];

bool matchesPreference(String? language, String? title, String preference) {
  final keys = switch (preference) {
    'Türkçe' => const ['tr', 'tur', 'türk', 'turk', 'turkish'],
    'English' => const ['en', 'eng', 'english'],
    'Deutsch' => const ['de', 'deu', 'ger', 'german', 'deutsch'],
    'Français' => const ['fr', 'fra', 'fre', 'french', 'français', 'francais'],
    'Español' => const ['es', 'spa', 'spanish', 'español', 'espanol'],
    'العربية' => const ['ar', 'ara', 'arabic', 'العربية'],
    'Русский' => const ['ru', 'rus', 'russian', 'русский'],
    _ => const <String>[],
  };
  if (keys.isEmpty) {
    return false;
  }
  final lang = (language ?? '').toLowerCase().replaceAll('_', '-');
  final name = (title ?? '').toLowerCase();
  for (final key in keys) {
    if (lang == key || lang.startsWith('$key-') || name.contains(key)) {
      return true;
    }
  }
  return false;
}

T? pickPreferred<T>(
  List<T> tracks,
  String primary,
  String secondary,
  String? Function(T track) language,
  String? Function(T track) title,
) {
  for (final preference in [primary, secondary]) {
    if (preference == 'Kapalı') {
      continue;
    }
    for (final track in tracks) {
      if (matchesPreference(language(track), title(track), preference)) {
        return track;
      }
    }
  }
  return null;
}

bool prefersTurkish(String? language, String? title) {
  final lang = (language ?? '').toLowerCase().replaceAll('_', '-');
  if (lang == 'tr' ||
      lang == 'tur' ||
      lang.startsWith('tr-') ||
      lang.startsWith('tur-')) {
    return true;
  }
  final name = (title ?? '').toLowerCase();
  return name.contains('türk') || name.contains('turk') || name.contains('turkish');
}

List<T> turkishFirst<T>(Iterable<T> items, bool Function(T item) turkish) {
  final first = <T>[];
  final rest = <T>[];
  for (final item in items) {
    if (turkish(item)) {
      first.add(item);
    } else {
      rest.add(item);
    }
  }
  return [...first, ...rest];
}

String upperTr(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    if (char == 'i') {
      buffer.write('İ');
    } else if (char == 'ı') {
      buffer.write('I');
    } else {
      buffer.write(char.toUpperCase());
    }
  }
  return buffer.toString();
}
