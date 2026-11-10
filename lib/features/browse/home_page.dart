import 'package:flutter/material.dart';

import '../../core/look.dart';
import '../../core/theme.dart';
import '../assist/library_mind.dart';
import '../library/user_library.dart';
import '../library/keep_store.dart';
import '../playback/media_entry.dart';
import '../shell/shell_section.dart';
import 'featured_slide.dart';
import 'mia_rail.dart';

class HomeRail {
  const HomeRail(this.id, this.title, this.empty);

  final String id;
  final String title;
  final String empty;
}

final homeRailEdit = ValueNotifier<VoidCallback?>(null);

const homeRailCatalog = [
  HomeRail('featured', 'Öne çıkanlar', 'Kaynağında başlık olunca burası dolar.'),
  HomeRail('because', 'İzlediklerinize göre', 'Birkaç başlık izleyince burası yaklaşır.'),
  HomeRail('recent', 'Son izledikleriniz', 'Son izlediklerin burada durur.'),
  HomeRail('list', 'Listem', 'Listeme eklediklerin burada durur.'),
  HomeRail('liked', 'Beğendiğiniz dizi ve filmler', 'Beğendiğin dizi ve filmler burada toplanır.'),
  HomeRail('paused', 'İzlemeye devam et', 'Yarıda kalan film, dizi veya yayın burada durur.'),
  HomeRail('live', 'Canlı TV', 'Canlı yayın eklenince burada durur.'),
  HomeRail('movies', 'Filmler', 'Film eklenince burada durur.'),
  HomeRail('series', 'Diziler', 'Dizi eklenince burada durur.'),
];

HomeRail? homeRailById(String id) {
  for (final rail in homeRailCatalog) {
    if (rail.id == id) {
      return rail;
    }
  }
  return null;
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.library,
    required this.keeps,
    required this.onPlay,
    required this.onResume,
    required this.onAdd,
  });

  final UserLibrary library;
  final KeepStore keeps;
  final ValueChanged<MediaEntry> onPlay;
  final void Function(MediaEntry entry, int? season, int? number) onResume;
  final VoidCallback onAdd;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _editing = false;

  @override
  void initState() {
    super.initState();
    homeRailEdit.value = _toggleEdit;
  }

  @override
  void dispose() {
    homeRailEdit.value = null;
    super.dispose();
  }

  void _toggleEdit() {
    setState(() => _editing = !_editing);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.library, widget.keeps]),
      builder: (context, _) {
        final look = LookScope.of(context);
        final pool = [
          for (final entry in widget.library.entries)
            if (entry.section == ShellSection.movies ||
                entry.section == ShellSection.series ||
                entry.section == ShellSection.live)
              entry,
        ];
        final phone = miaIsPhone(context);
        final wide = !phone;
        final top = MediaQuery.paddingOf(context).top + (phone ? 100 : 76);
        final skip = widget.keeps.doneIds();
        final recent = widget.keeps.recentIn(pool);
        final favorites = widget.keeps.favoritesIn(pool);
        final paused = widget.keeps.unfinishedEpisodes(pool);
        if (pool.isEmpty) {
          return ListView(
            padding: EdgeInsets.fromLTRB(wide ? 48 : 20, top, wide ? 48 : 20, phone ? 96 : 28),
            children: [
              _EmptyHome(onAdd: widget.onAdd),
            ],
          );
        }
        final rails = [
          for (final id in look.homeRails)
            if (homeRailById(id) != null) homeRailById(id)!,
        ];
        final hero = rails.any((rail) => rail.id == 'featured')
            ? _picks('featured', pool, recent, favorites, paused, skip).take(6).toList()
            : const <_Pick>[];
        final top10 = offeredTitles([
          for (final entry in pool)
            if ((entry.section == ShellSection.movies || entry.section == ShellSection.series) &&
                !skip.contains(entry.id))
              entry,
        ]).take(10).toList();
        final gutter = RailMetrics.of(context).gutter;
        return ListView(
          padding: EdgeInsets.only(bottom: phone ? 108 : 40),
          children: [
            if (hero.isEmpty || _editing) SizedBox(height: top),
            if (_editing)
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextButton(onPressed: _toggleEdit, child: const Text('Bitti')),
                    const HomeRailEditor(),
                  ],
                ),
              ),
            if (hero.isNotEmpty && !_editing)
              FeaturedSlide(
                entries: [for (final pick in hero) pick.entry],
                library: widget.library,
                billboard: true,
                fullBleed: true,
                onPlay: (entry) {
                  for (final pick in hero) {
                    if (pick.entry.id == entry.id) {
                      _RailBlock.openPick(pick, widget.onPlay, widget.onResume);
                      return;
                    }
                  }
                },
              ),
            for (final (index, rail) in rails.indexed)
              if (rail.id != 'featured') ...[
                _RailBlock(
                  library: widget.library,
                  rail: rail,
                  picks: _picks(rail.id, pool, recent, favorites, paused, skip),
                  onPlay: widget.onPlay,
                  onResume: widget.onResume,
                  showEmpty: _editing,
                ),
                if (top10.length >= 5 && index == _top10Slot(rails))
                  MiaRail(
                    title: 'Bugünün Top 10 listesi',
                    height: RailMetrics.of(context).poster * 1.5,
                    itemCount: top10.length,
                    itemBuilder: (context, i) {
                      final entry = top10[i];
                      return RankedTile(
                        rank: i + 1,
                        tile: MiaTile(
                          title: entry.title,
                          artwork: entry.artwork,
                          width: RailMetrics.of(context).poster,
                          onTap: () => widget.onPlay(entry),
                        ),
                      );
                    },
                  ),
              ],
            if (rails.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: Text(
                  'Tablo kalmadı. Düzenle ile yeniden ekleyebilirsin.',
                  style: MiaType.manrope(14, 500, color: const Color(0xFFB3B3B3)),
                ),
              ),
          ],
        );
      },
    );
  }

  List<_Pick> _picks(
    String id,
    List<MediaEntry> pool,
    List<MediaEntry> recent,
    List<MediaEntry> favorites,
    List<OpenEpisode> paused,
    Set<String> skip,
  ) {
    List<_Pick> plain(List<MediaEntry> entries) {
      final shown = entries.length > 18 ? entries.sublist(0, 18) : entries;
      return [for (final entry in shown) _Pick(entry)];
    }

    return switch (id) {
      'featured' => plain(featuredMix(pool, skip: skip)),
      'because' => plain(becauseYouWatched(pool, recent, skip: skip)),
      'recent' => plain(recent),
      'list' => plain(favorites),
      'liked' => plain([
        for (final entry in favorites)
          if (entry.section == ShellSection.movies || entry.section == ShellSection.series) entry,
      ]),
      'paused' => [
        for (final item in paused.take(18))
          _Pick(item.entry, title: item.title, season: item.season, number: item.number),
      ],
      'live' => plain([for (final entry in pool) if (entry.section == ShellSection.live) entry]),
      'movies' => plain(offeredTitles([
        for (final entry in pool)
          if (entry.section == ShellSection.movies && !skip.contains(entry.id)) entry,
      ])),
      'series' => plain(offeredTitles([
        for (final entry in pool)
          if (entry.section == ShellSection.series && !skip.contains(entry.id)) entry,
      ])),
      _ => const [],
    };
  }
}

class _Pick {
  const _Pick(this.entry, {String? title, this.season, this.number}) : title = title ?? '';

  final MediaEntry entry;
  final String title;
  final int? season;
  final int? number;

  String get label => title.isEmpty ? entry.title : title;

  bool get episode => season != null || number != null;
}

class _RailBlock extends StatelessWidget {
  const _RailBlock({
    required this.library,
    required this.rail,
    required this.picks,
    required this.onPlay,
    required this.onResume,
    required this.showEmpty,
  });

  final UserLibrary library;
  final HomeRail rail;
  final List<_Pick> picks;
  final ValueChanged<MediaEntry> onPlay;
  final void Function(MediaEntry entry, int? season, int? number) onResume;
  final bool showEmpty;

  static void openPick(
    _Pick pick,
    ValueChanged<MediaEntry> onPlay,
    void Function(MediaEntry entry, int? season, int? number) onResume,
  ) {
    if (pick.episode) {
      onResume(pick.entry, pick.season, pick.number);
      return;
    }
    onPlay(pick.entry);
  }

  @override
  Widget build(BuildContext context) {
    if (picks.isEmpty && !showEmpty) {
      return const SizedBox.shrink();
    }
    final metrics = RailMetrics.of(context);
    if (picks.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(metrics.gutter, 0, metrics.gutter, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rail.title, style: MiaType.outfit(20, 700, color: Colors.white)),
            const SizedBox(height: 6),
            Text(rail.empty, style: MiaType.manrope(13, 500, color: const Color(0xFFB3B3B3))),
          ],
        ),
      );
    }
    final shown = picks.length > 18 ? picks.sublist(0, 18) : picks;
    final live = rail.id == 'live';
    final resume = rail.id == 'paused';
    final shape = live ? TileShape.live : (resume ? TileShape.landscape : TileShape.poster);
    final width = live ? metrics.live : (resume ? metrics.landscape : metrics.poster);
    final sample = MiaTile(title: '', width: width, shape: shape);
    return MiaRail(
      title: rail.title,
      height: sample.height,
      itemCount: shown.length,
      itemBuilder: (context, index) {
        final pick = shown[index];
        final entry = pick.entry;
        return MiaTile(
          title: pick.label,
          artwork: resume ? (entry.backdrop ?? entry.artwork) : entry.artwork,
          width: width,
          shape: shape,
          note: pick.episode
              ? [
                  if (pick.season != null) 'S${pick.season}',
                  if (pick.number != null) 'B${pick.number}',
                ].join(' · ')
              : null,
          onTap: () => openPick(pick, onPlay, onResume),
        );
      },
    );
  }
}

int _top10Slot(List<HomeRail> rails) {
  for (final (index, rail) in rails.indexed) {
    if (rail.id != 'featured') {
      return index;
    }
  }
  return -1;
}

class HomeRailEditor extends StatelessWidget {
  const HomeRailEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final look = LookScope.of(context);
    final active = look.homeRails;
    final idle = [for (final rail in homeRailCatalog) if (!active.contains(rail.id)) rail];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ana sayfa tabloları', style: MiaType.manrope(15, 700, color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              'Sırayı değiştir, kaldır ya da yeniden ekle.',
              style: MiaType.manrope(13, 500, color: const Color(0xFFB3B3B3)),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < active.length; index++)
              _RailLine(
                title: homeRailById(active[index])?.title ?? active[index],
                onUp: index == 0
                    ? null
                    : () {
                        final next = [...active];
                        final item = next.removeAt(index);
                        next.insert(index - 1, item);
                        look.setHomeRails(next);
                      },
                onDown: index == active.length - 1
                    ? null
                    : () {
                        final next = [...active];
                        final item = next.removeAt(index);
                        next.insert(index + 1, item);
                        look.setHomeRails(next);
                      },
                onRemove: () => look.setHomeRails([...active]..remove(active[index])),
              ),
            if (active.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  'Görünen tablo yok.',
                  style: MiaType.manrope(13, 500, color: const Color(0xFFB3B3B3)),
                ),
              ),
            if (idle.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Ekle', style: MiaType.manrope(13, 700, color: Colors.white)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final rail in idle)
                    ActionChip(
                      label: Text(rail.title),
                      onPressed: () => look.setHomeRails([...active, rail.id]),
                      labelStyle: MiaType.manrope(13, 650, color: Colors.white),
                      backgroundColor: const Color(0xFF2A2A2A),
                      side: const BorderSide(color: Color(0xFF3A3A3A)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RailLine extends StatelessWidget {
  const _RailLine({required this.title, required this.onUp, required this.onDown, required this.onRemove});

  final String title;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: MiaType.manrope(14, 650, color: Colors.white))),
        IconButton(tooltip: 'Yukarı', onPressed: onUp, icon: const Icon(Icons.arrow_upward, size: 18)),
        IconButton(tooltip: 'Aşağı', onPressed: onDown, icon: const Icon(Icons.arrow_downward, size: 18)),
        IconButton(tooltip: 'Kaldır', onPressed: onRemove, icon: const Icon(Icons.close, size: 18)),
      ],
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ana sayfa hazır', style: MiaType.outfit(28, 700, color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            'Kaynak başlık döndürünce öne çıkanlar, öneriler ve izlediklerin burada karışır.',
            style: MiaType.manrope(15, 500, color: const Color(0xFFB3B3B3)),
          ),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ).copyWith(side: MiaTheme.lightFocusRing),
            onPressed: onAdd,
            child: Text('Kaynak ekle', style: MiaType.manrope(14, 700, color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
