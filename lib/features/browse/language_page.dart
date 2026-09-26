import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../library/user_library.dart';
import '../playback/media_entry.dart';
import '../playback/track_labels.dart';
import '../shell/shell_section.dart';
import 'cover_art.dart';

enum BrowseVoice { original, dub, subtitle }

const browseVoiceLabels = {
  BrowseVoice.original: 'Orijinal dil',
  BrowseVoice.dub: 'Dublaj',
  BrowseVoice.subtitle: 'Altyazı',
};

class LanguageBrowsePage extends StatefulWidget {
  const LanguageBrowsePage({super.key, required this.library, required this.onPlay});

  final UserLibrary library;
  final ValueChanged<MediaEntry> onPlay;

  @override
  State<LanguageBrowsePage> createState() => _LanguageBrowsePageState();
}

class _LanguageBrowsePageState extends State<LanguageBrowsePage> {
  var _movies = true;
  var _series = true;
  var _voice = BrowseVoice.dub;
  var _language = 'Türkçe';

  @override
  Widget build(BuildContext context) {
    final phone = miaIsPhone(context);
    return Scaffold(
      backgroundColor: context.mia.background,
      appBar: AppBar(title: const Text('Dillere Göre Gözat')),
      body: ListenableBuilder(
        listenable: widget.library,
        builder: (context, _) {
          final hits = [
            for (final entry in widget.library.entries)
              if (browseKeeps(entry, movies: _movies, series: _series, voice: _voice, language: _language)) entry,
          ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ne olsun', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Diziler'),
                            selected: _series,
                            onSelected: (value) => setState(() => _series = value),
                          ),
                          FilterChip(
                            label: const Text('Filmler'),
                            selected: _movies,
                            onSelected: (value) => setState(() => _movies = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text('Ses', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final voice in BrowseVoice.values)
                            ChoiceChip(
                              label: Text(browseVoiceLabels[voice]!),
                              selected: _voice == voice,
                              onSelected: (_) => setState(() => _voice = voice),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text('Dil', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final language in spokenLanguages)
                            ChoiceChip(
                              label: Text(language),
                              selected: _language == language,
                              onSelected: (_) => setState(() => _language = language),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        hits.isEmpty ? 'Bu seçimde kayıt yok' : '${hits.length} kayıt',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              if (hits.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: phone ? 3 : 6,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.62,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final entry = hits[index];
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return PosterCard(
                            title: entry.title,
                            artwork: entry.artwork,
                            width: constraints.maxWidth,
                            onTap: () => widget.onPlay(entry),
                          );
                        },
                      );
                    }, childCount: hits.length),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

bool browseKeeps(
  MediaEntry entry, {
  required bool movies,
  required bool series,
  required BrowseVoice voice,
  required String language,
}) {
  final kind = entry.section == ShellSection.movies
      ? movies
      : entry.section == ShellSection.series
      ? series
      : false;
  if (!kind) {
    return false;
  }
  final text = '${entry.title} ${entry.group} ${entry.genre ?? ''}'.toLowerCase();
  if (!_voiceHit(text, voice)) {
    return false;
  }
  return _languageHit(text, language);
}

bool _voiceHit(String text, BrowseVoice voice) {
  final dub = text.contains('dublaj') || _token(text, 'dub');
  final sub =
      text.contains('altyaz') || text.contains('subtitle') || text.contains('altyazı') || _token(text, 'sub');
  final original = text.contains('orijinal') || text.contains('original');
  return switch (voice) {
    BrowseVoice.dub => dub,
    BrowseVoice.subtitle => sub,
    BrowseVoice.original => original || (!dub && !sub),
  };
}

bool _languageHit(String text, String language) {
  if (_named(text, language)) {
    return true;
  }
  final plainTurkish =
      language == 'Türkçe' &&
      !_namedOther(text, 'Türkçe') &&
      (_voiceHit(text, BrowseVoice.dub) || _voiceHit(text, BrowseVoice.subtitle));
  if (plainTurkish) {
    return true;
  }
  return false;
}

bool _named(String text, String language) {
  for (final phrase in _phrases[language] ?? const <String>[]) {
    if (text.contains(phrase)) {
      return true;
    }
  }
  final tokens = _tokens(text);
  for (final code in _codes[language] ?? const <String>[]) {
    if (tokens.contains(code)) {
      return true;
    }
  }
  return false;
}

bool _namedOther(String text, String language) {
  for (final item in spokenLanguages) {
    if (item != language && _named(text, item)) {
      return true;
    }
  }
  return false;
}

Set<String> _tokens(String text) {
  return text.split(RegExp(r'[^a-zçğıöşü0-9]+')).where((token) => token.isNotEmpty).toSet();
}

bool _token(String text, String code) => _tokens(text).contains(code);

const _phrases = {
  'Türkçe': ['türkçe', 'turkce', 'turkish'],
  'English': ['english', 'ingilizce'],
  'Deutsch': ['deutsch', 'german', 'almanca'],
  'Français': ['français', 'francais', 'french', 'fransızca', 'fransizca'],
  'Español': ['español', 'espanol', 'spanish', 'ispanyolca'],
  'العربية': ['arabic', 'arapça', 'arapca'],
  'Русский': ['russian', 'rusça', 'rusca'],
};

const _codes = {
  'Türkçe': ['tr', 'tur'],
  'English': ['en', 'eng'],
  'Deutsch': ['de', 'deu', 'ger'],
  'Français': ['fr', 'fra'],
  'Español': ['es', 'spa'],
  'العربية': ['ar', 'ara'],
  'Русский': ['ru', 'rus'],
};
