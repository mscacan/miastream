import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../browse/cover_art.dart';
import '../browse/cover_store.dart';
import '../library/user_library.dart';
import '../library/user_source.dart';
import '../library/keep_store.dart';
import 'media_entry.dart';
import 'playback_bus.dart';
import 'player_page.dart';
import 'source_loader.dart';

class SeriesPage extends StatefulWidget {
  const SeriesPage({
    super.key,
    required this.loader,
    required this.source,
    required this.seriesId,
    required this.title,
    this.artwork,
    this.entryId,
    this.library,
    this.bus,
    this.keeps,
  });

  final SourceLoader loader;
  final UserSource source;
  final int seriesId;
  final String title;
  final String? artwork;
  final String? entryId;
  final UserLibrary? library;
  final PlaybackBus? bus;
  final KeepStore? keeps;

  @override
  State<SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends State<SeriesPage> {
  late final Future<List<Episode>> _episodes = widget.loader.episodes(
    widget.source,
    widget.seriesId,
  );
  int? _season;

  List<int> _seasons(List<Episode> episodes) {
    final seasons = <int>[];
    for (final episode in episodes) {
      final season = episode.season;
      if (season != null && !seasons.contains(season)) {
        seasons.add(season);
      }
    }
    return seasons;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mia.background,
      body: FutureBuilder<List<Episode>>(
        future: _episodes,
        builder: (context, snapshot) {
          final episodes = snapshot.data ?? const <Episode>[];
          final seasons = _seasons(episodes);
          final selected = _season ?? (seasons.isEmpty ? null : seasons.first);
          final shown = [
            for (final episode in episodes)
              if (seasons.length <= 1 || episode.season == selected) episode,
          ];
          final wide = MediaQuery.sizeOf(context).width >= 800;
          final gutter = wide ? 56.0 : 20.0;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: widget.artwork == null ? 88 : (wide ? 520 : 240),
                backgroundColor: context.mia.background,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  background: widget.artwork == null
                      ? const SizedBox.shrink()
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            CoverImage(url: widget.artwork!, fit: BoxFit.cover),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0x33000000), Color(0xFF000000)],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              if (snapshot.connectionState != ConnectionState.done)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                const SliverFillRemaining(child: Center(child: Text('Bölüm listesi okunamadı')))
              else if (episodes.isEmpty)
                const SliverFillRemaining(child: Center(child: Text('Bölüm yok')))
              else ...[
                if (seasons.length > 1)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 56,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
                        children: [
                          for (final season in seasons)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('Sezon $season'),
                                selected: selected == season,
                                showCheckmark: false,
                                onSelected: (_) => setState(() => _season = season),
                                labelStyle: const TextStyle(color: Colors.white),
                                selectedColor: const Color(0xFF3A3A3A),
                                backgroundColor: const Color(0xFF2A2A2A),
                                side: const BorderSide(color: Color(0xFF3A3A3A)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final episode = shown[index];
                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: gutter, vertical: wide ? 10 : 6),
                        leading: ArtworkThumb(artwork: episode.artwork ?? widget.artwork),
                        title: Text(episode.title),
                        subtitle: Text(_episodeLine(episode)),
                        trailing: const Icon(Icons.play_arrow),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => PlayerPage(
                                start: episodes.indexOf(episode),
                                library: widget.library,
                                bus: widget.bus,
                                keeps: widget.keeps,
                                cues: [
                                  for (final item in episodes)
                                    PlaybackCue(
                                      id: widget.entryId,
                                      title: item.title,
                                      url: item.url,
                                      artwork: item.artwork ?? widget.artwork,
                                      seriesTitle: widget.title,
                                      season: item.season,
                                      number: item.number,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: shown.length,
                  ),
                ),
              ],
            ],
          );
        },
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
