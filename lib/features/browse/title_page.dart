import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/device.dart';
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
import 'cover_store.dart';
import 'mia_rail.dart';
import 'poster_ink.dart';

const _ground = Color(0xFF0B0B0F);

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

  void _play() {
    if (widget.entry.url != null) {
      _watchMovie();
    } else {
      _watchEpisode(0);
    }
  }

  String? get _art => _brief.backdrop ?? widget.entry.artwork;

  /// Gerçek yatay görsel; afişin kendisi değilse.
  String? get _wideArt {
    final backdrop = _brief.backdrop;
    if (backdrop == null || backdrop == widget.entry.artwork) {
      return null;
    }
    return backdrop;
  }

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
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 800;
    final gutter = RailMetrics.of(context).gutter;
    final showTabs = _brief.episodes.isNotEmpty;
    final similarOn = !showTabs || _detailTab == 1;
    return Scaffold(
      backgroundColor: _ground,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 40),
            children: [
              _hero(size, wide, gutter, showTabs),
              if (!wide)
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
                  child: _facts(wide, centered: true),
                ),
              if (showTabs)
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, wide ? 8 : 16, gutter, 6),
                  child: Row(
                    children: [
                      _DetailTab(label: 'Bölümler', selected: _detailTab == 0, onTap: () => setState(() => _detailTab = 0)),
                      const SizedBox(width: 26),
                      _DetailTab(label: 'Benzerleri', selected: _detailTab == 1, onTap: () => setState(() => _detailTab = 1)),
                    ],
                  ),
                ),
              if (showTabs && _detailTab == 0) ...[
                if (_seasons.length > 1)
                  SizedBox(
                    height: 54,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 6),
                      children: [
                        for (final season in _seasons)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _SeasonPill(
                              label: 'Sezon $season',
                              selected: (_season ?? _seasons.first) == season,
                              onTap: () => setState(() => _season = season),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                for (var i = 0; i < _episodeRows().length; i++) _episodeTile(i, wide, gutter),
              ],
              if (similarOn && widget.similar.isNotEmpty) ...[
                const SizedBox(height: 18),
                _similar(),
              ],
            ],
          ),
          Positioned(
            left: wide ? gutter - 8 : 10,
            top: MediaQuery.paddingOf(context).top + 12,
            child: _GlassCircle(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Geri',
              autofocus: false,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(Size size, bool wide, double gutter, bool showTabs) {
    final wideArt = _wideArt;
    final poster = widget.entry.artwork;
    final live = widget.entry.section == ShellSection.live;
    final height = wide ? (size.height * 0.84).clamp(520.0, 900.0) : (size.height * 0.56).clamp(360.0, 540.0);
    return SizedBox(
      key: const Key('title-hero'),
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: _ground),
          if (wideArt != null)
            CoverImage(
              url: wideArt,
              cacheWidth: MiaDevice.isTv ? 1280 : (wide ? 1920 : 900),
              alignment: const Alignment(0.6, -0.3),
            )
          else if (poster != null) ...[
            Opacity(
              opacity: 0.5,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 44, sigmaY: 44, tileMode: TileMode.decal),
                child: CoverImage(url: poster, cacheWidth: 200, fallback: const SizedBox.shrink()),
              ),
            ),
            Align(
              alignment: wide ? const Alignment(0.72, -0.1) : const Alignment(0, 0.15),
              child: _PosterStage(art: poster, title: widget.entry.title, live: live, height: height * (wide ? 0.6 : 0.62)),
            ),
          ] else
            TypographicPoster(title: widget.entry.title),
          if (wide)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xF20B0B0F), Color(0xB30B0B0F), Color(0x1A0B0B0F), Color(0x000B0B0F)],
                  stops: [0, 0.32, 0.62, 0.85],
                ),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x990B0B0F), Color(0x000B0B0F), Color(0x000B0B0F), Color(0xD90B0B0F), _ground],
                stops: [0, 0.2, 0.55, 0.88, 1],
              ),
            ),
          ),
          if (wide)
            Positioned(
              left: gutter,
              right: gutter,
              bottom: 36,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 660),
                  child: _facts(wide, centered: false),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _facts(bool wide, {required bool centered}) {
    final align = centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        _KindLine(entry: widget.entry, centered: centered),
        const SizedBox(height: 12),
        Text(
          widget.entry.title,
          maxLines: wide ? 2 : 3,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          overflow: TextOverflow.ellipsis,
          style: MiaType.outfit(wide ? 60 : 32, 800, height: 0.98, letterSpacing: wide ? -1.8 : -0.8, color: Colors.white)
              .copyWith(shadows: const [Shadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 4))]),
        ),
        const SizedBox(height: 14),
        _metaRow(centered),
        const SizedBox(height: 22),
        _actions(wide),
        const SizedBox(height: 18),
        if (_loading)
          const SizedBox(
            width: 120,
            child: LinearProgressIndicator(minHeight: 2, color: Color(0xFFE50914), backgroundColor: Color(0x33FFFFFF)),
          ),
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Ayrıntı okunamadı. Kapak ve başlık listeden geldi.',
              style: MiaType.manrope(13, 500, color: Colors.white54),
            ),
          ),
        _plot(centered),
        if (_brief.director != null) _credit('Yönetmen', _brief.director!, centered),
        if (_brief.cast != null) _credit('Oyuncular', _brief.cast!, centered),
      ],
    );
  }

  Widget _metaRow(bool centered) {
    final soft = MiaType.manrope(15, 650, color: const Color(0xFFD6D6DC));
    final rating = _brief.rating;
    final genre = _brief.genre ?? _genreFallback();
    final length = _brief.lengthLabel;
    final seasons = _seasons.length;
    final bits = <Widget>[
      if (rating != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 19, color: Color(0xFFFFC53D)),
            const SizedBox(width: 3),
            Text(rating, style: MiaType.manrope(15, 800, color: Colors.white)),
          ],
        ),
      if (_brief.year != null) Text(_brief.year!, style: soft),
      if (seasons > 1) Text('$seasons Sezon', style: soft) else if (length != null) Text(length, style: soft),
      if (widget.entry.section != ShellSection.live) const _OutlineChip(text: 'HD'),
      if (genre != null) Text(genre, style: soft, maxLines: 1, overflow: TextOverflow.ellipsis),
    ];
    return Wrap(
      alignment: centered ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: bits,
    );
  }

  Widget _actions(bool wide) {
    final play = FilledButton.icon(
      autofocus: MiaDevice.isTv,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        disabledBackgroundColor: const Color(0x66FFFFFF),
        minimumSize: Size(wide ? 0 : double.infinity, wide ? 54 : 48),
        padding: EdgeInsets.symmetric(horizontal: wide ? 34 : 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ).copyWith(side: MiaTheme.lightFocusRing),
      onPressed: _canWatch ? _play : null,
      icon: Icon(Icons.play_arrow_rounded, size: wide ? 36 : 30),
      label: Text(_playLabel(), style: MiaType.manrope(wide ? 18 : 16, 800, color: Colors.black)),
    );
    final tools = [
      ListenableBuilder(
        listenable: widget.keeps,
        builder: (context, _) {
          final marked = widget.keeps.isFavorite(widget.entry.id);
          return _GlassCircle(
            icon: marked ? Icons.check_rounded : Icons.add_rounded,
            tooltip: marked ? 'Listemden çıkar' : 'Listeme ekle',
            label: wide ? null : 'Listem',
            onTap: () => widget.keeps.toggleFavorite(widget.entry.id),
          );
        },
      ),
      ListenableBuilder(
        listenable: widget.downloads,
        builder: (context, _) => _GlassCircle(
          icon: widget.downloads.has(_downloadTargetId) ? Icons.download_done_rounded : Icons.download_rounded,
          tooltip: _downloadLabel(),
          label: wide ? null : _downloadLabel(),
          onTap: _canDownload ? _downloadPrimary : null,
        ),
      ),
      _GlassCircle(
        icon: Icons.cast_rounded,
        tooltip: 'Yansıt',
        label: wide ? null : 'Yansıt',
        onTap: () => showCastSheet(context, url: widget.entry.url),
      ),
    ];
    if (!wide) {
      return Column(
        children: [
          play,
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: tools),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        play,
        for (final tool in tools) ...[const SizedBox(width: 12), tool],
      ],
    );
  }

  String _playLabel() {
    if (widget.entry.url != null || _brief.episodes.isEmpty) {
      return 'Oynat';
    }
    final first = _brief.episodes.first;
    if (first.season == null && first.number == null) {
      return 'Oynat';
    }
    return 'S${first.season ?? 1}:B${first.number ?? 1} Oynat';
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

  String? _genreFallback() {
    final group = widget.entry.group.trim();
    if (group.isEmpty || group == 'Filmler' || group == 'Diziler' || group == 'Kayıtlar') {
      return null;
    }
    return group;
  }

  Widget _plot(bool centered) {
    final text = _brief.plot;
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: _plotOpen ? 14 : 3,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          overflow: TextOverflow.ellipsis,
          style: MiaType.manrope(16, 500, height: 1.55, color: const Color(0xFFE2E2E8)),
        ),
        if (text.length > 160)
          TextButton(
            onPressed: () => setState(() => _plotOpen = !_plotOpen),
            child: Text(_plotOpen ? 'Daha az' : 'Devamını oku'),
          ),
      ],
    );
  }

  Widget _credit(String label, String value, bool centered) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: ', style: MiaType.manrope(14, 500, color: const Color(0xFF8C8C96))),
            TextSpan(text: value, style: MiaType.manrope(14, 600, color: const Color(0xFFD6D6DC))),
          ],
        ),
        maxLines: 2,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        overflow: TextOverflow.ellipsis,
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

  Widget _episodeTile(int index, bool wide, double gutter) {
    final row = _episodeRows()[index];
    final episode = row.episode;
    final id = '${widget.entry.id}-s${episode.season ?? 0}-b${episode.number ?? row.index}';
    return ListenableBuilder(
      listenable: widget.downloads,
      builder: (context, _) {
        final saved = widget.downloads.has(id);
        final fraction = widget.downloads.fraction(id);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter - 12, vertical: 2),
          child: _EpisodeCard(
            number: episode.number ?? index + 1,
            title: episode.title,
            line: _episodeLine(episode),
            artwork: episode.artwork ?? _art,
            wide: wide,
            saved: saved,
            fraction: fraction,
            onPlay: () => _watchEpisode(row.index),
            onDownload: saved || fraction != null
                ? null
                : () => widget.downloads.save(
                      id: id,
                      title: '${widget.entry.title} · ${episode.title}',
                      url: episode.url,
                      artwork: episode.artwork ?? _art,
                    ),
          ),
        );
      },
    );
  }

  Widget _similar() {
    final metrics = RailMetrics.of(context);
    return MiaRail(
      title: 'Benzer içerikler',
      height: metrics.poster * 1.5,
      itemCount: widget.similar.length,
      itemBuilder: (context, index) {
        final entry = widget.similar[index];
        return MiaTile(
          title: entry.title,
          artwork: entry.artwork,
          width: metrics.poster,
          shape: entry.section == ShellSection.live ? TileShape.live : TileShape.poster,
          onTap: () => widget.onOpen(entry),
        );
      },
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

class _KindLine extends StatelessWidget {
  const _KindLine({required this.entry, required this.centered});

  final MediaEntry entry;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    if (entry.section == ShellSection.live) {
      return const LiveBadge(big: true);
    }
    final kind = entry.section == ShellSection.series ? 'D İ Z İ' : 'F İ L M';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('M', style: MiaType.outfit(22, 900, height: 1, color: const Color(0xFFE50914))),
        const SizedBox(width: 8),
        Text(kind, style: MiaType.manrope(13, 800, color: const Color(0xFFE6E6EA)).copyWith(letterSpacing: 2.4)),
      ],
    );
  }
}

class _OutlineChip extends StatelessWidget {
  const _OutlineChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0x99FFFFFF)),
      ),
      child: Text(text, style: MiaType.manrope(11, 800, height: 1.3, color: const Color(0xFFE6E6EA))),
    );
  }
}

class _PosterStage extends StatelessWidget {
  const _PosterStage({required this.art, required this.title, required this.live, required this.height});

  final String art;
  final String title;
  final bool live;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (live) {
      return Container(
        width: height * 1.4,
        height: height * 0.8,
        padding: EdgeInsets.all(height * 0.12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const RadialGradient(colors: [Color(0x26FFFFFF), Color(0x05FFFFFF)]),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: CoverImage(url: art, fit: BoxFit.contain, cacheWidth: 640, fallback: const SizedBox.shrink()),
      );
    }
    return Container(
      width: height * 2 / 3,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0xCC000000), blurRadius: 60, offset: Offset(0, 28))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CoverImage(url: art, cacheWidth: 720, fallback: TypographicPoster(title: title)),
      ),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  const _GlassCircle({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.label,
    this.autofocus = false,
  });

  final IconData icon;
  final String tooltip;
  final String? label;
  final VoidCallback? onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final circle = Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: const Color(0x40FFFFFF),
            shape: const CircleBorder(side: BorderSide(color: Color(0x66FFFFFF), width: 1.5)),
            child: InkWell(
              autofocus: autofocus,
              customBorder: const CircleBorder(),
              focusColor: const Color(0x66FFFFFF),
              onTap: onTap,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(icon, color: onTap == null ? Colors.white38 : Colors.white, size: 26),
              ),
            ),
          ),
        ),
      ),
    );
    if (label == null) {
      return circle;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        circle,
        const SizedBox(height: 6),
        Text(label!, style: MiaType.manrope(12, 650, color: const Color(0xFFCFCFD6))),
      ],
    );
  }
}

class _SeasonPill extends StatelessWidget {
  const _SeasonPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : const Color(0xFF1B1B21),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: MiaType.manrope(14, 750, height: 1.2, color: selected ? Colors.black : const Color(0xFFD6D6DC)),
          ),
        ),
      ),
    );
  }
}

class _EpisodeCard extends StatefulWidget {
  const _EpisodeCard({
    required this.number,
    required this.title,
    required this.line,
    required this.artwork,
    required this.wide,
    required this.saved,
    required this.fraction,
    required this.onPlay,
    required this.onDownload,
  });

  final int number;
  final String title;
  final String line;
  final String? artwork;
  final bool wide;
  final bool saved;
  final double? fraction;
  final VoidCallback onPlay;
  final VoidCallback? onDownload;

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  var _lit = false;

  @override
  Widget build(BuildContext context) {
    final thumbWidth = widget.wide ? 210.0 : 136.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _lit ? const Color(0xFF1B1B22) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _lit ? const Color(0x33FFFFFF) : Colors.transparent),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.onPlay,
          onHover: (value) => setState(() => _lit = value),
          onFocusChange: (value) => setState(() => _lit = value),
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (widget.wide)
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${widget.number}',
                      style: MiaType.outfit(26, 700, color: const Color(0xFF8C8C96)),
                    ),
                  ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: thumbWidth,
                    height: thumbWidth * 9 / 16,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Color(0xFF1B1B21)),
                        if (widget.artwork != null)
                          CoverImage(url: widget.artwork!, cacheWidth: 420, fallback: TypographicPoster(title: widget.title)),
                        AnimatedOpacity(
                          opacity: _lit ? 1 : 0.0,
                          duration: const Duration(milliseconds: 160),
                          child: const ColoredBox(
                            color: Color(0x66000000),
                            child: Center(child: Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 44)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MiaType.manrope(widget.wide ? 16 : 14, 750, height: 1.3, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.line, style: MiaType.manrope(13, 600, color: const Color(0xFF9A9AA4))),
                      if (widget.fraction != null) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: widget.fraction,
                          minHeight: 3,
                          color: const Color(0xFFE50914),
                          backgroundColor: const Color(0x33FFFFFF),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: widget.saved ? 'İndirildi' : 'İndir',
                  onPressed: widget.onDownload,
                  icon: Icon(
                    widget.saved ? Icons.download_done_rounded : Icons.download_rounded,
                    color: widget.saved ? Colors.white : const Color(0xFFB9B9C2),
                  ),
                ),
              ],
            ),
          ),
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
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: MiaType.outfit(20, selected ? 750 : 550, color: selected ? Colors.white : const Color(0xFF8C8C96)),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: selected ? 28 : 0,
              height: 3,
              decoration: BoxDecoration(color: const Color(0xFFE50914), borderRadius: BorderRadius.circular(2)),
            ),
          ],
        ),
      ),
    );
  }
}
