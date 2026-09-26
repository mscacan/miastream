import 'package:flutter/material.dart';

import '../../core/look.dart';
import '../../core/theme.dart';
import '../browse/cover_art.dart';
import '../library/user_library.dart';
import '../playback/media_entry.dart';
import '../playback/title_facts.dart';
import '../shell/shell_section.dart';
import 'library_mind.dart';

class BotPage extends StatefulWidget {
  const BotPage({super.key, required this.library, required this.onPlay});

  final UserLibrary library;
  final ValueChanged<MediaEntry> onPlay;

  @override
  State<BotPage> createState() => _BotPageState();
}

class _BotPageState extends State<BotPage> {
  var _kind = BotKind.either;
  double? _minRating;
  var _voice = BotVoice.either;
  String? _genre;
  var _span = BotSpan.either;
  List<MediaEntry>? _found;
  final _facts = <String, TitleBrief>{};
  final _factAsked = <String>{};
  var _dirty = false;
  var _editing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dirty) {
      return;
    }
    final look = LookScope.of(context);
    _kind = BotKind.values.byName(look.botKind);
    _minRating = look.botMinRating;
    _voice = BotVoice.values.byName(look.botVoice);
    _genre = look.botGenre;
    _span = BotSpan.values.byName(look.botSpan);
    _found = look.botAsked ? botMatches(widget.library.entries, _askNow()) : null;
    final found = _found;
    if (found != null) {
      _fillFacts(found);
    }
  }

  BotAsk _askNow() {
    return BotAsk(kind: _kind, minRating: _minRating, voice: _voice, genre: _genre, span: _span);
  }

  void _remember({bool asked = false}) {
    LookScope.of(context).setBot(
      kind: _kind.name,
      minRating: _minRating,
      voice: _voice.name,
      genre: _genre,
      span: _span.name,
      asked: asked || _found != null,
    );
  }

  void _ask() {
    _dirty = true;
    final look = LookScope.of(context);
    if (_voice == BotVoice.dub) {
      look.setAudioPrimary('Türkçe');
      look.setSkipSubtitle(true);
    } else if (_voice == BotVoice.original) {
      look.setAudioPrimary('English');
      look.setSubtitlePrimary('Türkçe');
      look.setSkipSubtitle(false);
    }
    final matches = botMatches(widget.library.entries, _askNow());
    setState(() {
      _found = matches;
      _editing = false;
    });
    _remember(asked: true);
    _fillFacts(matches);
  }

  void _fillFacts(List<MediaEntry> matches) {
    for (final entry in matches) {
      if (!_factAsked.add(entry.id)) {
        continue;
      }
      final thin = oneBreath(entry.plot) == null ||
          entry.genre == null ||
          entry.minutes == null ||
          entry.rating == null ||
          entry.rating!.trim().isEmpty;
      if (!thin) {
        continue;
      }
      _loadFact(entry);
    }
  }

  Future<void> _loadFact(MediaEntry entry) async {
    final source = widget.library.sourceById(entry.sourceId);
    if (source == null) {
      return;
    }
    try {
      final brief = (await widget.library.loader.describe(source, entry)).fillFrom(entry);
      if (!mounted) {
        return;
      }
      setState(() => _facts[entry.id] = brief);
    } catch (_) {}
  }

  String _summary() {
    final kind = switch (_kind) {
      BotKind.movie => 'Film',
      BotKind.series => 'Dizi',
      BotKind.either => 'Film ya da dizi',
    };
    final rating = _minRating == null ? 'IMDb fark etmez' : 'IMDb ${_minRating!.toInt()}+';
    final voice = switch (_voice) {
      BotVoice.dub => 'Türkçe dublaj',
      BotVoice.original => 'Orijinal ses',
      BotVoice.either => 'Ses fark etmez',
    };
    final genre = _genre == null ? 'Tür fark etmez' : _label(_genre!);
    final span = switch (_span) {
      BotSpan.short => '45 dk altı',
      BotSpan.medium => '90 dk civarı',
      BotSpan.long => '2 saat ve üzeri',
      BotSpan.either => 'Süre fark etmez',
    };
    return '$kind, $rating, $voice, $genre, $span';
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final found = _found;
    final bottom = wide ? 28.0 : MediaQuery.paddingOf(context).bottom + 148;
    return ListView(
      padding: EdgeInsets.fromLTRB(wide ? 48 : 16, 8, wide ? 48 : 16, bottom),
      children: [
        Text('Sana göre', style: MiaType.outfit(28, 700, color: Colors.white)),
        if (found == null || _editing) ...[
          const SizedBox(height: 6),
          Text(
            'Birkaç seçim yap. Listenin içinden en yakın başlıkları çıkarırım.',
            style: MiaType.manrope(14, 500, color: const Color(0xFFB3B3B3)),
          ),
        ],
        const SizedBox(height: 18),
        if (found != null && !_editing)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _summary(),
                  style: MiaType.manrope(15, 650, color: Colors.white),
                ),
              ),
              IconButton(
                tooltip: 'Değiştir',
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
              ),
            ],
          )
        else ...[
        _Ask(
          title: 'Ne izleyelim?',
          children: [
            _pick('Fark etmez', _kind == BotKind.either, () => _choose(() => _kind = BotKind.either)),
            _pick('Dizi', _kind == BotKind.series, () => _choose(() => _kind = BotKind.series)),
            _pick('Film', _kind == BotKind.movie, () => _choose(() => _kind = BotKind.movie)),
          ],
        ),
        _Ask(
          title: 'En az puan',
          children: [
            _pick('Fark etmez', _minRating == null, () => _choose(() => _minRating = null)),
            _pick('6+', _minRating == 6, () => _choose(() => _minRating = 6)),
            _pick('7+', _minRating == 7, () => _choose(() => _minRating = 7)),
            _pick('8+', _minRating == 8, () => _choose(() => _minRating = 8)),
          ],
        ),
        _Ask(
          title: 'Ses',
          children: [
            _pick('Fark etmez', _voice == BotVoice.either, () => _choose(() => _voice = BotVoice.either)),
            _pick('Türkçe dublaj', _voice == BotVoice.dub, () => _choose(() => _voice = BotVoice.dub)),
            _pick('Orijinal ses', _voice == BotVoice.original, () => _choose(() => _voice = BotVoice.original)),
          ],
        ),
        _Ask(
          title: 'Tür',
          children: [
            _pick('Fark etmez', _genre == null, () => _choose(() => _genre = null)),
            for (final name in ['dram', 'komedi', 'gerilim', 'aksiyon', 'romantik', 'korku'])
              _pick(_label(name), _genre == name, () => _choose(() => _genre = name)),
          ],
        ),
        _Ask(
          title: 'Süre',
          children: [
            _pick('Fark etmez', _span == BotSpan.either, () => _choose(() => _span = BotSpan.either)),
            _pick('45 dk altı', _span == BotSpan.short, () => _choose(() => _span = BotSpan.short)),
            _pick('90 dk civarı', _span == BotSpan.medium, () => _choose(() => _span = BotSpan.medium)),
            _pick('2 saat ve üzeri', _span == BotSpan.long, () => _choose(() => _span = BotSpan.long)),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _ask,
          child: Text('Uygun olanı bul', style: MiaType.manrope(16, 700, color: Colors.black)),
        ),
        ],
        if (found != null) ...[
          const SizedBox(height: 22),
          Text(
            found.isEmpty ? 'Bu seçime uyan kayıt yok' : 'Sana yakın',
            style: MiaType.outfit(20, 700, color: Colors.white),
          ),
          const SizedBox(height: 10),
          if (found.isEmpty)
            Text(
              'Puanı veya süreyi gevşet. Ses tercihi oynatıcıya yazıldı.',
              style: MiaType.manrope(14, 500, color: const Color(0xFFB3B3B3)),
            )
          else
            for (final entry in found) _matchCard(entry),
        ],
      ],
    );
  }

  Widget _matchCard(MediaEntry entry) {
    final brief = _facts[entry.id];
    final plot = oneBreath(brief?.plot ?? entry.plot);
    final genre = (brief?.genre ?? entry.genre)?.trim();
    final minutes = brief?.minutes ?? entry.minutes;
    final rating = _imdb(brief?.rating ?? entry.rating);
    final voice = voiceLabel(entry);
    final kind = entry.section == ShellSection.series ? 'Dizi' : 'Film';
    final bits = [
      kind,
      ?rating,
      if (genre != null && genre.isNotEmpty) genre,
      if (minutes != null && minutes > 0) '$minutes dk',
      ?voice,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => widget.onPlay(entry),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ArtworkThumb(artwork: entry.artwork, width: 72, height: 104),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MiaType.manrope(16, 700, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bits.join(' · '),
                        style: MiaType.manrope(13, 600, color: const Color(0xFFB3B3B3)),
                      ),
                      if (plot != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          plot,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MiaType.manrope(13, 500, color: const Color(0xFFD0D0D0)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _choose(VoidCallback apply) {
    _dirty = true;
    setState(apply);
    _remember();
  }

  Widget _pick(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        labelStyle: MiaType.manrope(13, 700, color: Colors.white),
        selectedColor: const Color(0xFFE50914),
        backgroundColor: const Color(0xFF2A2A2A),
        side: BorderSide(color: selected ? const Color(0xFFE50914) : const Color(0xFF3A3A3A)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _Ask extends StatelessWidget {
  const _Ask({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: MiaType.manrope(15, 700, color: Colors.white)),
          const SizedBox(height: 8),
          Wrap(children: children),
        ],
      ),
    );
  }
}

String _label(String token) {
  return switch (token) {
    'dram' => 'Dram',
    'komedi' => 'Komedi',
    'gerilim' => 'Gerilim',
    'aksiyon' => 'Aksiyon',
    'romantik' => 'Romantik',
    'korku' => 'Korku',
    _ => token,
  };
}

String? _imdb(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty || text == '0') {
    return null;
  }
  if (text.toLowerCase().contains('imdb')) {
    return text;
  }
  return 'IMDb $text';
}
