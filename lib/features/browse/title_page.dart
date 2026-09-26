import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../epg/epg_page.dart';
import '../library/user_library.dart';
import '../library/keep_store.dart';
import '../offline/download_store.dart';
import '../playback/media_entry.dart';
import '../playback/playback_bus.dart';
import '../playback/player_page.dart';
import '../playback/title_facts.dart';
import '../sync/lounge_link.dart';
import '../shell/shell_section.dart';
import 'cover_art.dart';
import 'cover_store.dart';

class TitlePage extends StatefulWidget {
  const TitlePage({
    super.key,
    required this.entry,
    required this.library,
    required this.bus,
    required this.downloads,
    required this.keeps,
    required this.link,
    required this.similar,
    required this.onOpen,
  });

  final MediaEntry entry;
  final UserLibrary library;
  final PlaybackBus bus;
  final DownloadStore downloads;
  final KeepStore keeps;
  final LoungeLink link;
  final List<MediaEntry> similar;
  final ValueChanged<MediaEntry> onOpen;

  @override
  State<TitlePage> createState() => _TitlePageState();
}

class _TitlePageState extends State<TitlePage> {
  late TitleBrief _brief = TitleBrief(
    plot: widget.entry.plot,
    genre: widget.entry.genre,
    year: widget.entry.year,
    minutes: widget.entry.minutes,
    rating: widget.entry.rating,
    director: widget.entry.director,
    cast: widget.entry.cast,
    backdrop: widget.entry.backdrop ?? widget.entry.artwork,
  );
  var _loading = true;
  var _failed = false;
  var _plotOpen = false;
  var _detailTab = 0;
  int? _season;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final source = widget.library.sourceById(widget.entry.sourceId);
    if (source == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final brief = await widget.library.loader.describe(source, widget.entry);
      if (!mounted) {
        return;
      }
      setState(() {
        _brief = brief;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _watchMovie() {
    if ((widget.entry.url == null || widget.entry.url!.isEmpty) && widget.entry.playCmd == null) {
      return;
    }
    _openPlayer([widget.entry.toCue()]);
  }

  void _watchEpisode(int start) {
    final episodes = _brief.episodes;
    if (episodes.isEmpty) {
      return;
    }
    _openPlayer(
      [
        for (final item in episodes)
          PlaybackCue(
            id: widget.entry.id,
            title: item.title,
            url: item.url,
            artwork: item.artwork ?? _art,
            seriesTitle: widget.entry.title,
            season: item.season,
            number: item.number,
          ),
      ],
      start: start,
    );
  }

  void _openPlayer(List<PlaybackCue> cues, {int start = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PlayerPage(
          cues: cues,
          start: start,
          library: widget.library,
          bus: widget.bus,
          keeps: widget.keeps,
          link: widget.link,
        ),
      ),
    );
  }

  String? get _art => _brief.backdrop ?? widget.entry.artwork;

  String get _primaryDownloadId {
    if (widget.entry.section == ShellSection.series) {
      return '${widget.entry.id}-ilk';
    }
    return widget.entry.id;
  }

  Future<void> _downloadPrimary() async {
    if (widget.entry.url != null) {
      await widget.downloads.save(
        id: widget.entry.id,
        title: widget.entry.title,
        url: widget.entry.url!,
        artwork: _art,
      );
      return;
    }
    if (_brief.episodes.isEmpty) {
      return;
    }
    final first = _brief.episodes.first;
    await widget.downloads.save(
      id: _primaryDownloadId,
      title: '${widget.entry.title} · ${first.title}',
      url: first.url,
      artwork: first.artwork ?? _art,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final art = _art;
    final showTabs = _brief.episodes.isNotEmpty;
    final similarOn = !showTabs || _detailTab == 1;
    final gutter = wide ? 56.0 : 16.0;
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListView(
        children: [
          SizedBox(
            key: const Key('title-hero'),
            height: wide ? 640 : 280,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF141414)),
                if (art != null) CoverImage(url: art, fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: wide ? Alignment.centerLeft : Alignment.topCenter,
                      end: wide ? Alignment.centerRight : Alignment.bottomCenter,
                      colors: wide
                          ? const [Color(0xF2000000), Color(0xB3000000), Color(0x00000000)]
                          : const [Color(0x66000000), Color(0x00000000), Color(0xFF000000)],
                      stops: wide ? const [0, 0.38, 0.72] : const [0, 0.55, 1],
                    ),
                  ),
                ),
                if (wide)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x33000000), Color(0x00000000), Color(0xFF000000)],
                        stops: [0, 0.45, 1],
                      ),
                    ),
                  ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      tooltip: 'Geri',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                ),
                if (wide)
                  Positioned(
                    left: gutter,
                    right: 72,
                    bottom: 28,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: _facts(wide, showTabs),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!wide)
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 0),
              child: _facts(wide, showTabs),
            ),
          if (showTabs && _detailTab == 0) ...[
            if (_seasons.length > 1)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
                  children: [
                    for (final season in _seasons)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('Sezon $season'),
                          selected: (_season ?? _seasons.first) == season,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _season = season),
                          labelStyle: MiaType.manrope(13, 650, color: Colors.white),
                          selectedColor: const Color(0xFF3A3A3A),
                          backgroundColor: const Color(0xFF2A2A2A),
                          side: const BorderSide(color: Color(0xFF3A3A3A)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                  ],
                ),
              ),
            for (var i = 0; i < _episodeRows().length; i++) _episodeTile(i, wide),
          ],
          if (similarOn && widget.similar.isNotEmpty) _similar(wide),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _facts(bool wide, bool showTabs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.entry.title,
          maxLines: wide ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: MiaType.outfit(wide ? 52 : 28, 700, height: 1.05, color: Colors.white),
        ),
        if (_meta().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_meta(), style: MiaType.manrope(wide ? 15 : 13, 600, color: const Color(0xFFB3B3B3))),
        ],
        const SizedBox(height: 14),
        _actions(wide),
        const SizedBox(height: 16),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Ayrıntı okunamadı. Kapak ve başlık listeden geldi.',
              style: MiaType.manrope(13, 500, color: Colors.white54),
            ),
          ),
        _plot(),
        if (_brief.director != null) _credit('Yönetmen', _brief.director!),
        if (_brief.cast != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Başroldekiler: ', style: MiaType.manrope(13, 500, color: Colors.white54)),
                  TextSpan(text: _brief.cast!, style: MiaType.manrope(13, 600, color: Colors.white70)),
                ],
              ),
            ),
          ),
        if (!wide) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ListenableBuilder(
                listenable: widget.keeps,
                builder: (context, _) {
                  final marked = widget.keeps.isFavorite(widget.entry.id);
                  return _PhoneTool(
                    icon: marked ? Icons.check : Icons.add,
                    label: 'Listem',
                    onTap: () => widget.keeps.toggleFavorite(widget.entry.id),
                  );
                },
              ),
              _PhoneTool(
                icon: Icons.ios_share,
                label: 'Yansıt',
                onTap: () => showCastSheet(context, url: widget.entry.url),
              ),
              ListenableBuilder(
                listenable: widget.downloads,
                builder: (context, _) => _PhoneTool(
                  icon: Icons.download_outlined,
                  label: _downloadLabel(),
                  onTap: _canDownload ? _downloadPrimary : null,
                ),
              ),
            ],
          ),
        ],
        if (showTabs) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              _DetailTab(
                label: 'Bölümler',
                selected: _detailTab == 0,
                onTap: () => setState(() => _detailTab = 0),
              ),
              _DetailTab(
                label: 'Benzerleri',
                selected: _detailTab == 1,
                onTap: () => setState(() => _detailTab = 1),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _actions(bool wide) {
    final play = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(horizontal: wide ? 22 : 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: _canWatch
          ? () {
              if (widget.entry.url != null) {
                _watchMovie();
              } else {
                _watchEpisode(0);
              }
            }
          : null,
      icon: const Icon(Icons.play_arrow, size: 28),
      label: Text('Oynat', style: MiaType.manrope(16, 700, color: Colors.black)),
    );
    final download = ListenableBuilder(
      listenable: widget.downloads,
      builder: (context, _) {
        return FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2A2A2A),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: wide ? 18 : 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: _canDownload ? _downloadPrimary : null,
          icon: const Icon(Icons.download, size: 20),
          label: Text(_phoneDownloadLabel(), style: MiaType.manrope(15, 700, color: Colors.white)),
        );
      },
    );
    if (!wide) {
      return Column(
        children: [
          SizedBox(width: double.infinity, child: play),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: download),
        ],
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        play,
        download,
        ListenableBuilder(
          listenable: widget.keeps,
          builder: (context, _) {
            final marked = widget.keeps.isFavorite(widget.entry.id);
            return _WideTool(
              icon: marked ? Icons.check : Icons.add,
              label: 'Listem',
              onTap: () => widget.keeps.toggleFavorite(widget.entry.id),
            );
          },
        ),
        _WideTool(
          icon: Icons.ios_share,
          label: 'Yansıt',
          onTap: () => showCastSheet(context, url: widget.entry.url),
        ),
      ],
    );
  }

  String _phoneDownloadLabel() {
    final base = _downloadLabel();
    if (base != 'İndir' || _brief.episodes.isEmpty) {
      return base;
    }
    final first = _brief.episodes.first;
    if (first.season == null && first.number == null) {
      return base;
    }
    return 'İndir: S${first.season ?? 1}:B${first.number ?? 1}';
  }

  bool get _canWatch {
    if (widget.entry.url != null) {
      return true;
    }
    return _brief.episodes.isNotEmpty;
  }

  bool get _canDownload {
    if (widget.downloads.has(_downloadTargetId) || widget.downloads.fraction(_downloadTargetId) != null) {
      return false;
    }
    if (widget.entry.url != null) {
      return true;
    }
    return _brief.episodes.isNotEmpty;
  }

  String get _downloadTargetId {
    return widget.entry.url != null ? widget.entry.id : _primaryDownloadId;
  }

  String _downloadLabel() {
    if (widget.downloads.has(_downloadTargetId)) {
      return 'İndirildi';
    }
    final fraction = widget.downloads.fraction(_downloadTargetId);
    if (fraction != null) {
      return '%${(fraction * 100).round()}';
    }
    if (widget.downloads.errors[_downloadTargetId] != null) {
      return 'Tekrar dene';
    }
    return 'İndir';
  }

  String _meta() {
    final bits = <String>[];
    final rating = _brief.rating;
    if (rating != null) {
      bits.add('★ $rating');
    }
    if (_brief.year != null) {
      bits.add(_brief.year!);
    }
    final length = _brief.lengthLabel;
    if (length != null) {
      bits.add(length);
    }
    final genre = _brief.genre ?? _genreFallback();
    if (genre != null) {
      bits.add(genre);
    }
    return bits.join('  ·  ');
  }

  String? _genreFallback() {
    final group = widget.entry.group.trim();
    if (group.isEmpty || group == 'Filmler' || group == 'Diziler' || group == 'Kayıtlar') {
      return null;
    }
    return group;
  }

  Widget _plot() {
    final text = _brief.plot;
    if (text == null || text.isEmpty) {
      if (_loading) {
        return const SizedBox(height: 8);
      }
      return Text(
        'Açıklama bu kayıtta yok.',
        style: MiaType.manrope(15, 500, color: Colors.white70),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: _plotOpen ? 12 : 3,
          overflow: TextOverflow.ellipsis,
          style: MiaType.manrope(16, 500, height: 1.45, color: Colors.white),
        ),
        if (text.length > 140)
          TextButton(
            onPressed: () => setState(() => _plotOpen = !_plotOpen),
            child: Text(_plotOpen ? 'Daha az' : 'Daha fazla'),
          ),
      ],
    );
  }

  Widget _credit(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label  ', style: MiaType.manrope(14, 500, color: Colors.white38)),
            TextSpan(text: value, style: MiaType.manrope(14, 600, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  List<int> get _seasons {
    final seasons = <int>[];
    for (final episode in _brief.episodes) {
      final season = episode.season;
      if (season != null && !seasons.contains(season)) {
        seasons.add(season);
      }
    }
    return seasons;
  }

  List<_EpisodeRow> _episodeRows() {
    final seasons = _seasons;
    final selected = _season ?? (seasons.isEmpty ? null : seasons.first);
    final rows = <_EpisodeRow>[];
    for (var i = 0; i < _brief.episodes.length; i++) {
      final episode = _brief.episodes[i];
      if (seasons.length > 1 && episode.season != selected) {
        continue;
      }
      rows.add(_EpisodeRow.item(i, episode));
    }
    return rows;
  }

  Widget _episodeTile(int index, bool wide) {
    final row = _episodeRows()[index];
    final episode = row.episode;
    final id = '${widget.entry.id}-s${episode.season ?? 0}-b${episode.number ?? row.index}';
    return ListenableBuilder(
      listenable: widget.downloads,
      builder: (context, _) {
        final saved = widget.downloads.has(id);
        final fraction = widget.downloads.fraction(id);
        return ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: wide ? 56 : 20),
          leading: ArtworkThumb(artwork: episode.artwork ?? _art),
          title: Text(episode.title),
          subtitle: Text(_episodeLine(episode)),
          trailing: IconButton(
            tooltip: saved ? 'İndirildi' : 'İndir',
            onPressed: saved || fraction != null
                ? null
                : () => widget.downloads.save(
                    id: id,
                    title: '${widget.entry.title} · ${episode.title}',
                    url: episode.url,
                    artwork: episode.artwork ?? _art,
                  ),
            icon: Icon(
              saved ? Icons.download_done : Icons.download,
              color: saved ? Colors.white : Colors.white70,
            ),
          ),
          onTap: () => _watchEpisode(row.index),
        );
      },
    );
  }

  Widget _similar(bool wide) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(wide ? 56 : 20, 0, 20, 12),
            child: Text('Benzer içerikler', style: MiaType.outfit(22, 650, color: Colors.white)),
          ),
          SizedBox(
            height: 248,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: wide ? 56 : 20),
              itemCount: widget.similar.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final entry = widget.similar[index];
                return PosterCard(
                  title: entry.title,
                  artwork: entry.artwork,
                  titleBelow: true,
                  width: wide ? 158 : 118,
                  onTap: () => widget.onOpen(entry),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _episodeLine(Episode episode) {
  final bits = <String>[];
  if (episode.season != null) {
    bits.add('Sezon ${episode.season}');
  }
  if (episode.number != null) {
    bits.add('Bölüm ${episode.number}');
  }
  return bits.isEmpty ? 'Bölüm' : bits.join(' · ');
}

class _EpisodeRow {
  const _EpisodeRow.item(this.index, this.episode);

  final int index;
  final Episode episode;
}

class _WideTool extends StatelessWidget {
  const _WideTool({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF2A2A2A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label, style: MiaType.manrope(15, 700, color: Colors.white)),
    );
  }
}

class _PhoneTool extends StatelessWidget {
  const _PhoneTool({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 4),
            Text(label, style: MiaType.manrope(11, 600, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _DetailTab extends StatelessWidget {
  const _DetailTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 12, 22, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: selected ? const Color(0xFFE50914) : Colors.transparent, width: 3),
          ),
        ),
        child: Text(label, style: MiaType.manrope(16, selected ? 700 : 500, color: Colors.white)),
      ),
    );
  }
}

