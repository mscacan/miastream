import 'package:flutter/material.dart';

import '../../core/look.dart';
import '../../core/theme.dart';
import '../assist/library_mind.dart';
import '../library/user_library.dart';
import '../lounge/seat_store.dart';
import '../playback/media_entry.dart';
import '../shell/shell_section.dart';
import 'cover_art.dart';
import 'featured_slide.dart';

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
    required this.seat,
    required this.onPlay,
    required this.onResume,
    required this.onAdd,
  });

  final UserLibrary library;
  final SeatStore seat;
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
      listenable: Listenable.merge([widget.library, widget.seat]),
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
        final skip = widget.seat.doneIds();
        final recent = widget.seat.recentIn(pool);
        final favorites = widget.seat.favoritesIn(pool);
        final paused = widget.seat.unfinishedEpisodes(pool);
        if (pool.isEmpty) {
          return ListView(
            padding: EdgeInsets.fromLTRB(wide ? 48 : 20, 8, wide ? 48 : 20, phone ? 96 : 28),
            children: [
              _EmptyHome(onAdd: widget.onAdd),
            ],
          );
        }
        final rails = [
          for (final id in look.homeRails)
            if (homeRailById(id) != null) homeRailById(id)!,
        ];
        return ListView(
          padding: EdgeInsets.fromLTRB(wide ? 48 : 16, wide ? 8 : 8, wide ? 48 : 16, phone ? 108 : 32),
          children: [
            if (_editing) ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _toggleEdit, child: const Text('Bitti')),
              ),
              const HomeRailEditor(),
              const SizedBox(height: 16),
            ],
            for (final rail in rails)
              _RailBlock(
                library: widget.library,
                rail: rail,
                picks: _picks(rail.id, pool, recent, favorites, paused, skip),
                onPlay: widget.onPlay,
                onResume: widget.onResume,
                showEmpty: _editing,
              ),
            if (rails.isEmpty)
              Text(
                'Tablo kalmadı. Düzenle ile yeniden ekleyebilirsin.',
                style: MiaType.manrope(14, 500, color: const Color(0xFFB3B3B3)),
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

  void _open(_Pick pick) {
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
    final featured = rail.id == 'featured' && picks.isNotEmpty;
    final shown = featured ? (picks.length > 8 ? picks.sublist(0, 8) : picks) : picks;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!featured) Text(rail.title, style: MiaType.outfit(20, 700, color: Colors.white)),
          if (!featured) const SizedBox(height: 10),
          if (picks.isEmpty)
            Text(rail.empty, style: MiaType.manrope(13, 500, color: const Color(0xFFB3B3B3)))
          else if (featured)
            FeaturedSlide(
              entries: [for (final pick in shown) pick.entry],
              library: library,
              billboard: true,
              onPlay: (entry) {
                for (final pick in shown) {
                  if (pick.entry.id == entry.id) {
                    _open(pick);
                    return;
                  }
                }
              },
            )
          else
            Builder(
              builder: (context) {
                final wide = MediaQuery.sizeOf(context).width >= 800;
                final live = rail.id == 'live';
                final big = wide && !live;
                return SizedBox(
                  height: live ? 112 : (big ? 420 : 210),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: shown.length > 18 ? 18 : shown.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final pick = shown[index];
                      return PosterCard(
                        title: pick.label,
                        artwork: pick.entry.artwork,
                        titleBelow: live,
                        width: live ? 168 : (big ? 224 : 112),
                        onTap: () => _open(pick),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
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
            ),
            onPressed: onAdd,
            child: Text('Kaynak ekle', style: MiaType.manrope(14, 700, color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
