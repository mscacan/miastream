import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../core/look.dart';
import '../../core/theme.dart';
import '../assist/library_mind.dart';
import '../library/user_library.dart';
import '../playback/media_entry.dart';
import 'cover_store.dart';
import '../shell/shell_section.dart';
import 'poster_ink.dart';

class PerdeView extends StatefulWidget {
  const PerdeView({
    super.key,
    required this.entries,
    required this.onPlay,
    this.library,
    this.contain = false,
    this.card = false,
    this.compact = false,
    this.listed,
    this.onList,
  });

  final List<MediaEntry> entries;
  final ValueChanged<MediaEntry> onPlay;
  final UserLibrary? library;
  final bool contain;
  final bool card;
  final bool compact;
  final bool Function(MediaEntry entry)? listed;
  final ValueChanged<MediaEntry>? onList;

  @override
  State<PerdeView> createState() => _PerdeViewState();
}

class _PerdeViewState extends State<PerdeView> {
  final PageController _pages = PageController();
  final Map<String, String> _blurbs = {};
  final Set<String> _blurbAsked = {};
  var _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.entries.isNotEmpty) {
        _wash(widget.entries.first);
        _loadBlurb(widget.entries.first);
      }
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _wash(MediaEntry entry) async {
    final look = LookScope.of(context);
    final art = entry.backdrop ?? entry.artwork;
    if (art == null) {
      look.setRoom(inkFor(entry.title));
      return;
    }
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(art, headers: const {'User-Agent': 'MiaStream'}),
        maximumColorCount: 8,
      );
      final color = palette.vibrantColor?.color ?? palette.dominantColor?.color ?? inkFor(entry.title);
      if (mounted) {
        look.setRoom(color);
      }
    } catch (_) {
      if (mounted) {
        look.setRoom(inkFor(entry.title));
      }
    }
  }

  String? _blurbOf(MediaEntry entry) {
    if (entry.section != ShellSection.series && entry.section != ShellSection.movies) {
      return null;
    }
    final local = oneBreath(entry.plot);
    if (local != null) {
      return local;
    }
    final cached = _blurbs[entry.id];
    if (cached == null || cached.isEmpty) {
      return null;
    }
    return cached;
  }

  Future<void> _loadBlurb(MediaEntry entry) async {
    if (entry.section != ShellSection.series && entry.section != ShellSection.movies) {
      return;
    }
    if (oneBreath(entry.plot) != null || _blurbs.containsKey(entry.id) || _blurbAsked.contains(entry.id)) {
      return;
    }
    final library = widget.library;
    final source = library?.sourceById(entry.sourceId);
    if (library == null || source == null) {
      return;
    }
    _blurbAsked.add(entry.id);
    try {
      final brief = await library.loader.describe(source, entry);
      if (!mounted) {
        return;
      }
      setState(() => _blurbs[entry.id] = oneBreath(brief.plot) ?? '');
    } catch (_) {
      if (mounted) {
        setState(() => _blurbs[entry.id] = '');
      }
    }
  }

  void _step(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.entries.length) {
      return;
    }
    _pages.animateToPage(next, duration: const Duration(milliseconds: 420), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.card) {
      return _CardBoard(
        pages: _pages,
        entries: widget.entries,
        contain: widget.contain,
        compact: widget.compact,
        listed: widget.listed,
        onList: widget.onList,
        onPlay: widget.onPlay,
        blurbOf: _blurbOf,
        onPage: (index) {
          setState(() => _index = index);
          _wash(widget.entries[index]);
          _loadBlurb(widget.entries[index]);
        },
      );
    }
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 800;
    final board = (size.height * (wide ? 0.82 : 0.68)).clamp(420.0, 820.0);
    final top = MediaQuery.paddingOf(context).top + (wide ? 78 : 64);
    return SizedBox(
      height: board,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.entries.length,
            onPageChanged: (index) {
              setState(() => _index = index);
              _wash(widget.entries[index]);
            },
            itemBuilder: (context, index) {
              final item = widget.entries[index];
              final art = item.backdrop ?? item.artwork;
              final breath = oneBreath(item.plot);
              final meta = [
                if (item.year != null && item.year!.isNotEmpty) item.year!,
                if (item.minutes != null && item.minutes! > 0) '${item.minutes} dk',
                if (item.genre != null && item.genre!.isNotEmpty) item.genre!,
              ].join('  ·  ');
              return Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xFF141414)),
                  if (art == null)
                    TypographicPoster(title: item.title)
                  else
                    CoverImage(
                      url: art,
                      fit: widget.contain ? BoxFit.contain : BoxFit.cover,
                      fallback: TypographicPoster(title: item.title),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xF2141414), Color(0xB3141414), Color(0x33141414), Color(0x00141414)],
                        stops: [0, 0.28, 0.55, 0.82],
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xFF141414), Color(0xCC141414), Color(0x00141414)],
                        stops: [0, 0.18, 0.55],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(wide ? 56 : 20, top, wide ? 120 : 20, wide ? 72 : 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: wide ? 520 : double.infinity,
                          child: Text(
                            item.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: MiaType.outfit(wide ? 64 : 36, 700, letterSpacing: -1.1, height: 0.96, color: Colors.white),
                          ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: MiaType.manrope(14, 600, color: const Color(0xFFE5E5E5))),
                        ],
                        if (breath != null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: wide ? 460 : double.infinity,
                            child: Text(
                              breath,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: MiaType.manrope(16, 500, color: const Color(0xFFE5E5E5)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: EdgeInsets.symmetric(horizontal: wide ? 26 : 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              onPressed: () => widget.onPlay(item),
                              icon: const Icon(Icons.play_arrow, size: 30),
                              label: Text('Oynat', style: MiaType.manrope(16, 700, color: Colors.black)),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xB36D6D6E),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: wide ? 22 : 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              onPressed: () => widget.onPlay(item),
                              icon: const Icon(Icons.info_outline, size: 24),
                              label: Text('Daha Fazla Bilgi', style: MiaType.manrope(16, 700, color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (item.rating != null && item.rating!.trim().isNotEmpty)
                    Positioned(
                      right: 0,
                      bottom: wide ? 120 : 48,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
                        decoration: const BoxDecoration(
                          color: Color(0x66333333),
                          border: Border(left: BorderSide(color: Colors.white, width: 3)),
                        ),
                        child: Text(item.rating!, style: MiaType.manrope(14, 700, color: Colors.white)),
                      ),
                    ),
                ],
              );
            },
          ),
          if (wide && widget.entries.length > 1) ...[
            Positioned(
              left: 0,
              top: top,
              bottom: 80,
              child: _BillboardArrow(icon: Icons.chevron_left, onTap: () => _step(-1)),
            ),
            Positioned(
              right: 0,
              top: top,
              bottom: 80,
              child: _BillboardArrow(icon: Icons.chevron_right, onTap: () => _step(1)),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardBoard extends StatelessWidget {
  const _CardBoard({
    required this.pages,
    required this.entries,
    required this.contain,
    this.compact = false,
    required this.onPlay,
    required this.onPage,
    required this.blurbOf,
    this.listed,
    this.onList,
  });

  final PageController pages;
  final List<MediaEntry> entries;
  final bool contain;
  final bool compact;
  final ValueChanged<MediaEntry> onPlay;
  final ValueChanged<int> onPage;
  final String? Function(MediaEntry entry) blurbOf;
  final bool Function(MediaEntry entry)? listed;
  final ValueChanged<MediaEntry>? onList;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 48 : 16, 8, wide ? 48 : 16, 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: const Color(0xFF1A1A1A),
          child: SizedBox(
            height: (wide ? 520 : 460) * (compact ? 0.5 : 1),
            child: PageView.builder(
              controller: pages,
              itemCount: entries.length,
              onPageChanged: onPage,
              itemBuilder: (context, page) {
                final item = entries[page];
                final art = item.backdrop ?? item.artwork;
                final saved = listed?.call(item) ?? false;
                final blurb = blurbOf(item);
                final meta = [
                  if (item.section == ShellSection.series) 'Dizi',
                  if (item.section == ShellSection.movies) 'Film',
                  if (item.section == ShellSection.live) 'Canlı',
                  if (item.genre != null && item.genre!.isNotEmpty) item.genre!,
                  if (item.group.trim().isNotEmpty &&
                      item.group != 'Canlı' &&
                      item.group != 'Kayıtlar' &&
                      item.group != 'Filmler' &&
                      item.group != 'Diziler')
                    item.group,
                  if (item.archiveHours != null && item.archiveHours! > 0) 'Geri alma ${item.archiveHours} saat',
                ].join('  ·  ');
                final play = switch (item.section) {
                  ShellSection.series => 'Diziyi Oynat',
                  ShellSection.movies => 'Filmi Oynat',
                  _ => 'Oynat',
                };
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0xFF1A1A1A)),
                    if (art == null)
                      TypographicPoster(title: item.title)
                    else
                      CoverImage(
                        url: art,
                        fit: contain ? BoxFit.contain : BoxFit.cover,
                        fallback: TypographicPoster(title: item.title),
                      ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0x33000000), Color(0xF0141414)],
                          stops: [0.35, 0.62, 1],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: MiaType.outfit(32, 700, letterSpacing: -0.6, height: 0.98, color: Colors.white),
                          ),
                          if (blurb != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              blurb,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: MiaType.manrope(13, 500, color: const Color(0xFFE5E5E5)),
                            ),
                          ],
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MiaType.manrope(12, 600, color: const Color(0xFFE5E5E5)),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => onPlay(item),
                                  icon: const Icon(Icons.play_arrow, size: 26),
                                  label: Text(play, style: MiaType.manrope(14, 700, color: Colors.black)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF3A3A3A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: onList == null ? null : () => onList!(item),
                                  icon: Icon(saved ? Icons.check : Icons.add, size: 20),
                                  label: Text('Listem', style: MiaType.manrope(14, 700, color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BillboardArrow extends StatelessWidget {
  const _BillboardArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x66141414),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          child: Icon(icon, color: Colors.white, size: 42),
        ),
      ),
    );
  }
}
