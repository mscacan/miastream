import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/look.dart';
import '../../core/theme.dart';
import '../assist/library_mind.dart';
import '../library/user_library.dart';
import '../library/user_source.dart';
import '../library/keep_store.dart';
import '../playback/media_entry.dart';
import '../shell/shell_section.dart';
import 'catalog_rails.dart';
import 'cover_art.dart';
import 'cover_store.dart';
import 'featured_slide.dart';
import 'perde_view.dart';
import 'poster_ink.dart';

class CatalogPage extends StatelessWidget {
  const CatalogPage({
    super.key,
    required this.section,
    required this.library,
    required this.keeps,
    required this.onAdd,
    required this.onPlay,
    this.onFilter,
  });

  final ShellSection section;
  final UserLibrary library;
  final KeepStore keeps;
  final VoidCallback onAdd;
  final ValueChanged<MediaEntry> onPlay;
  final ValueChanged<ShellSection>? onFilter;

  Future<void> _newShelf(BuildContext context) async {
    final field = TextEditingController();
    final saved = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Raf kur'),
          content: TextField(
            controller: field,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Raf adı'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(context, field.text), child: const Text('Kur')),
          ],
        );
      },
    );
    field.dispose();
    if (saved != null) {
      keeps.createShelf(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([library, keeps]),
      builder: (context, _) {
        final items = library.items;
        final all = library.entriesFor(section);
        final voice = LookScope.of(context).catalogVoice;
        final entries = section == ShellSection.movies || section == ShellSection.series
            ? [for (final entry in all) if (catalogKeeps(entry, voice)) entry]
            : all;
        final favorites = keeps.favoritesIn(entries);
        final recent = keeps.recentIn(entries);
        final rails = section == ShellSection.movies || section == ShellSection.series
            ? smartRails(entries, watched: recent)
            : const <CatalogRail>[];
        final frames = keeps.framesIn(entries);
        final brief = keeps.shortOnes(entries);
        final contain = section == ShellSection.live;
        final phone = miaIsPhone(context);
        final topInset = phone ? MediaQuery.paddingOf(context).top + 100 : 0.0;
        return CustomScrollView(
          slivers: [
            if (topInset > 0) SliverToBoxAdapter(child: SizedBox(height: topInset)),
            if (!phone && onFilter != null)
              const SliverToBoxAdapter(child: SizedBox(height: 76)),
            if (!phone && onFilter != null)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    children: [
                      for (final item in [ShellSection.live, ShellSection.series, ShellSection.movies, ShellSection.bot])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(item.label),
                            selected: item == section,
                            showCheckmark: false,
                            onSelected: (_) => onFilter!(item),
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
              ),
            if (section == ShellSection.movies || section == ShellSection.series)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(phone ? 16 : 48, 8, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final item in [('either', 'Tümü'), ('dub', 'Türkçe dublaj'), ('original', 'Orijinal')])
                        ChoiceChip(
                          label: Text(item.$2),
                          selected: voice == item.$1,
                          showCheckmark: false,
                          onSelected: (_) => LookScope.of(context).setCatalogVoice(item.$1),
                          labelStyle: MiaType.manrope(13, 650, color: Colors.white),
                          selectedColor: const Color(0xFF3A3A3A),
                          backgroundColor: const Color(0xFF2A2A2A),
                          side: const BorderSide(color: Color(0xFF3A3A3A)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                    ],
                  ),
                ),
              ),
            if (entries.isEmpty)
              SliverToBoxAdapter(
                child: _Hero(
                  section: section,
                  items: items,
                  onAdd: onAdd,
                  featured: null,
                  onPlay: onPlay,
                  loading: library.isLoading,
                  message: library.messages.isEmpty ? null : library.messages.first,
                ),
              )
            else if (section == ShellSection.live)
              SliverToBoxAdapter(
                child: PerdeView(
                  entries: entries,
                  library: library,
                  onPlay: onPlay,
                  contain: contain,
                  card: true,
                  compact: true,
                  listed: (entry) => keeps.isFavorite(entry.id),
                  onList: (entry) => keeps.toggleFavorite(entry.id),
                ),
              )
            else if (section == ShellSection.series || section == ShellSection.movies)
              SliverToBoxAdapter(
                child: _TurnStrip(
                  entries: entries,
                  section: section,
                  library: library,
                  onPlay: onPlay,
                ),
              ),
            if (section == ShellSection.live)
              SliverToBoxAdapter(
                child: _LiveSeriesRow(library: library, keeps: keeps, onPlay: onPlay),
              ),
            if (recent.isNotEmpty)
              SliverToBoxAdapter(
                child: _EntryStrip(
                  title: section == ShellSection.movies || section == ShellSection.series
                      ? 'İzlemeye devam et'
                      : 'Son izledikleriniz',
                  entries: section == ShellSection.live
                      ? recent.take(5).toList()
                      : (recent.length > 12 ? recent.sublist(0, 12) : recent),
                  onPlay: onPlay,
                  contain: contain,
                  noteFor: (entry) => section == ShellSection.live ? _channelNote(entry) : _leftAt(keeps, entry),
                  progressFor: section == ShellSection.live ? null : (entry) => _watchFraction(keeps, entry),
                ),
              ),
            if (frames.isNotEmpty)
              SliverToBoxAdapter(
                child: _FrameStrip(entries: frames, keeps: keeps, onPlay: onPlay),
              ),
            if (brief.isNotEmpty)
              SliverToBoxAdapter(
                child: _EntryStrip(
                  title: '40 dakikam var',
                  entries: brief,
                  onPlay: onPlay,
                  contain: contain,
                ),
              ),
            if (favorites.isNotEmpty)
              SliverToBoxAdapter(
                child: _EntryStrip(
                  title: 'Favoriler',
                  entries: favorites,
                  onPlay: onPlay,
                  contain: contain,
                ),
              ),
            for (final shelf in keeps.shelves)
              if (keeps.shelfEntries(shelf, entries).isNotEmpty)
                SliverToBoxAdapter(
                  child: _EntryStrip(
                    title: shelf.name,
                    entries: keeps.shelfEntries(shelf, entries),
                    onPlay: onPlay,
                    contain: contain,
                  ),
                ),
            for (final rail in rails)
                SliverToBoxAdapter(
                  child: _EntryStrip(
                    title: rail.title,
                    entries: rail.entries,
                    onPlay: onPlay,
                    contain: false,
                    ranked: rail.ranked,
                  ),
                ),
            if (section == ShellSection.movies || section == ShellSection.series)
              SliverToBoxAdapter(
                child: _CategoryBoard(
                  rows: _categoryTables(entries),
                  onPlay: onPlay,
                ),
              )
            else
              for (final row in _freshRows(entries, section, rails))
                SliverToBoxAdapter(
                  child: _EntryStrip(
                    title: row.$1,
                    entries: row.$2,
                    onPlay: onPlay,
                    contain: section == ShellSection.live,
                  ),
                ),
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: TextButton.icon(
                    onPressed: () => _newShelf(context),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Raf kur'),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _Row(title: 'Kaynakların', items: items, onAdd: onAdd),
            ),
            if (phone) const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        );
      },
    );
  }
}

String? _channelNote(MediaEntry entry) {
  final bits = <String>[
    if (entry.group.trim().isNotEmpty && entry.group != 'Canlı' && entry.group != 'Kayıtlar') entry.group.trim(),
    if (entry.archiveHours != null && entry.archiveHours! > 0) 'Geri alma ${entry.archiveHours} saat',
    if (entry.rating != null && entry.rating!.trim().isNotEmpty) entry.rating!.trim(),
  ];
  return bits.isEmpty ? null : bits.join(' · ');
}

String? _seriesNote(MediaEntry entry) {
  final bits = <String>[
    if (entry.rating != null && entry.rating!.trim().isNotEmpty) entry.rating!.trim(),
    if (entry.genre != null && entry.genre!.trim().isNotEmpty) entry.genre!.trim(),
    if (entry.group.trim().isNotEmpty && entry.group != 'Diziler' && entry.group != 'Kayıtlar') entry.group.trim(),
    if (voiceLabel(entry) != null) voiceLabel(entry)!,
  ];
  return bits.isEmpty ? null : bits.take(3).join(' · ');
}

String? _leftAt(KeepStore keeps, MediaEntry entry) {
  for (final item in keeps.unfinishedEpisodes([entry])) {
    if (item.season != null || item.number != null) {
      final bits = <String>[
        if (item.season != null) 'Sezon ${item.season}',
        if (item.number != null) 'Bölüm ${item.number}',
        '${(item.ms / 60000).round()} dk',
      ];
      return bits.join(' · ');
    }
  }
  final spot = keeps.spotOf(entry.id);
  if (spot == null || spot.ms <= 8000) {
    return null;
  }
  return '${(spot.ms / 60000).round()} dk';
}

double? _watchFraction(KeepStore keeps, MediaEntry entry) {
  final minutes = entry.minutes;
  if (minutes == null || minutes <= 0) {
    return null;
  }
  final spot = keeps.spotOf(entry.id);
  final ms = spot?.ms ?? keeps.unfinishedEpisodes([entry]).firstOrNull?.ms;
  if (ms == null || ms <= 8000) {
    return null;
  }
  return ms / (minutes * 60000);
}

class _TurnStrip extends StatefulWidget {
  const _TurnStrip({
    required this.entries,
    required this.section,
    required this.library,
    required this.onPlay,
  });

  final List<MediaEntry> entries;
  final ShellSection section;
  final UserLibrary library;
  final ValueChanged<MediaEntry> onPlay;

  @override
  State<_TurnStrip> createState() => _TurnStripState();
}

class _TurnStripState extends State<_TurnStrip> {
  late final int _shift = DateTime.now().microsecondsSinceEpoch;

  @override
  Widget build(BuildContext context) {
    final rows = spotlight(widget.entries, widget.section, shift: _shift);
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 24 : 12, 4, wide ? 24 : 12, 8),
      child: FeaturedSlide(
        entries: rows,
        library: widget.library,
        onPlay: widget.onPlay,
        billboard: true,
      ),
    );
  }
}

class _LiveSeriesRow extends StatefulWidget {
  const _LiveSeriesRow({required this.library, required this.keeps, required this.onPlay});

  final UserLibrary library;
  final KeepStore keeps;
  final ValueChanged<MediaEntry> onPlay;

  @override
  State<_LiveSeriesRow> createState() => _LiveSeriesRowState();
}

class _LiveSeriesRowState extends State<_LiveSeriesRow> {
  late final int _shift = DateTime.now().microsecondsSinceEpoch;

  @override
  Widget build(BuildContext context) {
    final series = [
      for (final entry in widget.library.entries)
        if (entry.section == ShellSection.series) entry,
    ];
    final watched = widget.keeps.recentIn(series);
    final rows = watched.take(5).toList();
    if (rows.length < 5) {
      for (final item in spotlight(series, ShellSection.series, shift: _shift)) {
        if (rows.length >= 5) {
          break;
        }
        if (rows.every((entry) => entry.id != item.id)) {
          rows.add(item);
        }
      }
    }
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    return _EntryStrip(
      title: watched.isEmpty ? 'Öne çıkan diziler' : 'Son izlediğin diziler',
      entries: rows,
      onPlay: widget.onPlay,
      contain: false,
      noteFor: _seriesNote,
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.section,
    required this.items,
    required this.onAdd,
    required this.featured,
    required this.onPlay,
    required this.loading,
    required this.message,
  });

  final ShellSection section;
  final List<UserSource> items;
  final VoidCallback onAdd;
  final MediaEntry? featured;
  final ValueChanged<MediaEntry> onPlay;
  final bool loading;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final source = items.isEmpty ? null : items.first;
    final playable = featured;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 800;
    final height = size.height < 640 ? 300.0 : (size.height * 0.58).clamp(380.0, 520.0);
    final artwork = playable?.artwork;
    final title = playable?.title ?? source?.label ?? 'Henüz kaynak yok';
    final live = section == ShellSection.live;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF141414)),
              if (artwork != null && !live)
                CoverImage(url: artwork, fit: BoxFit.cover),
              if (artwork != null && live)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: wide ? 72 : 24),
                    child: SizedBox(
                      height: height * 0.46,
                      child: CoverImage(
                        url: artwork,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xF5101010),
                      Color(0xCC101010),
                      Color(0x33101010),
                      Color(0x00101010),
                    ],
                    stops: [0, 0.32, 0.58, 0.86],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xE6101010), Color(0x00101010)],
                    stops: [0, 0.42],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(wide ? 40 : 20, 20, wide ? 40 : 20, wide ? 36 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: wide ? 560 : double.infinity,
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MiaType.outfit(
                          wide ? 58 : 34,
                          700,
                          letterSpacing: -1.2,
                          height: 0.95,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      source == null
                          ? _emptyLine(section)
                          : loading
                              ? 'Liste okunuyor'
                              : message ?? '${section.label}  ·  ${playable?.group ?? 'Senin listen'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MiaType.manrope(wide ? 16 : 13, 500, color: const Color(0xFFE5E5E5)),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (playable != null) ...[
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: EdgeInsets.symmetric(horizontal: wide ? 22 : 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => onPlay(playable),
                            icon: const Icon(Icons.play_arrow, size: 28),
                            label: Text('Oynat', style: MiaType.manrope(16, 700, color: Colors.black)),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF3E3E3E),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: wide ? 18 : 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => onPlay(playable),
                            icon: const Icon(Icons.info_outline, size: 22),
                            label: Text(
                              'Daha Fazla Bilgi',
                              style: MiaType.manrope(15, 650, color: Colors.white),
                            ),
                          ),
                        ] else if (source == null)
                          FilledButton(onPressed: onAdd, child: const Text('Kaynak ekle')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.items, required this.onAdd});

  final String title;
  final List<UserSource> items;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          SizedBox(
            height: 188,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final wide = MediaQuery.sizeOf(context).width >= 800;
                if (index == items.length) {
                  return PosterCard(
                    title: 'Ekle',
                    onTap: onAdd,
                    add: true,
                    titleBelow: true,
                    width: wide ? 148 : 112,
                  );
                }
                return PosterCard(
                  title: items[index].label,
                  titleBelow: true,
                  width: wide ? 148 : 112,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryStrip extends StatelessWidget {
  const _EntryStrip({
    required this.title,
    required this.entries,
    required this.onPlay,
    required this.contain,
    this.noteFor,
    this.progressFor,
    this.ranked = false,
  });

  final String title;
  final List<MediaEntry> entries;
  final ValueChanged<MediaEntry> onPlay;
  final bool contain;
  final String? Function(MediaEntry entry)? noteFor;
  final double? Function(MediaEntry entry)? progressFor;
  final bool ranked;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final gutter = wide ? 48.0 : 16.0;
    final cardWidth = contain ? 168.0 : (wide ? 176.0 : 118.0);
    final rowHeight = contain ? 120.0 : (wide ? 250.0 : 176.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 8),
            child: Text(title, style: MiaType.outfit(wide ? 22 : 18, 700, color: Colors.white)),
          ),
          SizedBox(
            height: rowHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: gutter),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final card = PosterCard(
                  title: entry.title,
                  artwork: entry.artwork,
                  titleBelow: contain,
                  width: cardWidth,
                  note: noteFor?.call(entry),
                  progress: progressFor?.call(entry),
                  onTap: () => onPlay(entry),
                );
                if (!ranked) {
                  return card;
                }
                return Row(
                  children: [
                    SizedBox(
                      width: wide ? 64 : 44,
                      child: Text(
                        '${index + 1}',
                        textAlign: TextAlign.right,
                        style: MiaType.outfit(wide ? 56 : 40, 700, color: const Color(0xFF4A4A4A)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    card,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameStrip extends StatelessWidget {
  const _FrameStrip({
    required this.entries,
    required this.keeps,
    required this.onPlay,
  });

  final List<MediaEntry> entries;
  final KeepStore keeps;
  final ValueChanged<MediaEntry> onPlay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Text('İzlemeye Devam Et', style: MiaType.outfit(20, 700, color: Colors.white)),
          ),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final spot = keeps.spotOf(entry.id);
                final frame = spot?.frame;
                final file = frame == null ? null : File(frame);
                final seen = (spot?.ms ?? 0) > 8000;
                return GestureDetector(
                  onTap: () => onPlay(entry),
                  child: SizedBox(
                    width: 148,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 96,
                            width: 148,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                const ColoredBox(color: Color(0xFF1A1A1A)),
                                if (file != null && file.existsSync())
                                  Image.file(file, fit: BoxFit.cover)
                                else if (entry.artwork != null)
                                  CoverImage(
                                    url: entry.artwork!,
                                    fallback: TypographicPoster(title: entry.title),
                                  )
                                else
                                  TypographicPoster(title: entry.title),
                                const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 36)),
                                if (seen)
                                  const Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: LinearProgressIndicator(
                                      value: 0.45,
                                      minHeight: 3,
                                      color: Color(0xFFE50914),
                                      backgroundColor: Color(0xFF4A4A4A),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.white, size: 18),
                            const Spacer(),
                            Expanded(
                              child: Text(
                                entry.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: MiaType.manrope(11, 600, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

List<(String, List<MediaEntry>)> _categoryTables(List<MediaEntry> entries) {
  return [for (final row in _rows(entries)) if (row.$2.length >= 4) row];
}

class _CategoryBoard extends StatelessWidget {
  const _CategoryBoard({required this.rows, required this.onPlay});

  final List<(String, List<MediaEntry>)> rows;
  final ValueChanged<MediaEntry> onPlay;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    final phone = miaIsPhone(context);
    final width = MediaQuery.sizeOf(context).width;
    final columns = phone ? 4 : (width >= 1200 ? 8 : 6);
    final gutter = phone ? 16.0 : 48.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kategoriler', style: MiaType.outfit(phone ? 18 : 22, 700, color: Colors.white)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
              final tileHeight = phone ? tileWidth * 1.08 : 96.0;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < rows.length; i++)
                    _CategoryTile(
                      title: rows[i].$1,
                      color: _categoryColors[i % _categoryColors.length],
                      width: tileWidth,
                      height: tileHeight,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => _CategoryShelf(
                              title: rows[i].$1,
                              entries: rows[i].$2,
                              onPlay: onPlay,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.title,
    required this.color,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final String title;
  final Color color;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final deep = Color.lerp(color, const Color(0xFF12080A), 0.42)!;
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, deep],
              ),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Center(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: MiaType.outfit(width < 96 ? 11 : 15, 700, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryShelf extends StatelessWidget {
  const _CategoryShelf({
    required this.title,
    required this.entries,
    required this.onPlay,
  });

  final String title;
  final List<MediaEntry> entries;
  final ValueChanged<MediaEntry> onPlay;

  @override
  Widget build(BuildContext context) {
    final phone = miaIsPhone(context);
    final columns = phone ? 3 : 6;
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        foregroundColor: Colors.white,
        title: Text(title, style: MiaType.outfit(18, 700, color: Colors.white)),
      ),
      body: GridView.builder(
        padding: EdgeInsets.fromLTRB(phone ? 16 : 48, 8, phone ? 16 : 48, 28),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 8,
          childAspectRatio: 0.62,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return LayoutBuilder(
            builder: (context, constraints) {
              return PosterCard(
                title: entry.title,
                artwork: entry.artwork,
                width: constraints.maxWidth,
                onTap: () => onPlay(entry),
              );
            },
          );
        },
      ),
    );
  }
}

const _categoryColors = <Color>[
  Color(0xFFC11119),
  Color(0xFF1D4E89),
  Color(0xFF0F6E56),
  Color(0xFFC47B12),
  Color(0xFF6D28A8),
  Color(0xFF0E7490),
  Color(0xFFBE185D),
  Color(0xFF3F6212),
  Color(0xFFC2410C),
  Color(0xFF1E3A8A),
  Color(0xFF7C2D12),
  Color(0xFF0F766E),
  Color(0xFF7E22CE),
];

List<(String, List<MediaEntry>)> _freshRows(
  List<MediaEntry> entries,
  ShellSection section,
  List<CatalogRail> rails,
) {
  if (section != ShellSection.movies && section != ShellSection.series) {
    return _rows(entries);
  }
  final used = <String>{
    for (final rail in rails)
      for (final entry in rail.entries) entry.id,
  };
  final rows = <(String, List<MediaEntry>)>[];
  for (final row in _rows(entries)) {
    final fresh = [for (final entry in row.$2) if (used.add(entry.id)) entry];
    if (fresh.length < 4) {
      continue;
    }
    rows.add((row.$1, fresh.length > 18 ? fresh.sublist(0, 18) : fresh));
  }
  return rows;
}

List<(String, List<MediaEntry>)> _rows(List<MediaEntry> entries) {
  final order = <String>[];
  final grouped = <String, List<MediaEntry>>{};
  for (final entry in entries) {
    final name = entry.group.trim().isEmpty ? 'Kayıtlar' : entry.group;
    final bucket = grouped.putIfAbsent(name, () {
      order.add(name);
      return <MediaEntry>[];
    });
    bucket.add(entry);
  }
  return [for (final name in order) (name, grouped[name]!)];
}

String _emptyLine(ShellSection section) {
  return switch (section) {
    ShellSection.live => 'Canlı yayınlar senin listenden gelir.',
    ShellSection.series => 'Diziler senin listenden, bölüm bölüm gelir.',
    ShellSection.movies => 'Filmler senin listenden gelir.',
    _ => 'Kendi listen buraya gelir.',
  };
}
