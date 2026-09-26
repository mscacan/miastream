import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../assist/library_mind.dart';
import '../library/user_library.dart';
import '../playback/media_entry.dart';
import '../shell/shell_section.dart';
import 'cover_store.dart';
import 'poster_ink.dart';

class FeaturedSlide extends StatefulWidget {
  const FeaturedSlide({
    super.key,
    required this.entries,
    required this.library,
    required this.onPlay,
    this.billboard = false,
  });

  final List<MediaEntry> entries;
  final UserLibrary library;
  final ValueChanged<MediaEntry> onPlay;
  final bool billboard;

  @override
  State<FeaturedSlide> createState() => _FeaturedSlideState();
}

class _FeaturedSlideState extends State<FeaturedSlide> {
  final _pages = PageController();
  Timer? _timer;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(covariant FeaturedSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries.length == widget.entries.length) {
      return;
    }
    if (_index >= widget.entries.length) {
      _index = 0;
    }
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    if (widget.entries.length < 2) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _step(1));
  }

  void _step(int delta) {
    final count = widget.entries.length;
    if (!mounted || count == 0) {
      return;
    }
    var next = (_index + delta) % count;
    if (next < 0) {
      next += count;
    }
    _pages.animateToPage(next, duration: const Duration(milliseconds: 420), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final count = widget.entries.length;
    final span = MediaQuery.sizeOf(context).width - (wide ? 96 : 32);
    final height = wide ? (span / 2.35).clamp(440.0, 560.0) : 430.0;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: count,
            onPageChanged: (index) {
              setState(() => _index = index);
              _arm();
            },
            itemBuilder: (context, index) {
              final entry = widget.entries[index];
              return _SlideCard(
                entry: entry,
                library: widget.library,
                onPlay: () => widget.onPlay(entry),
              );
            },
          ),
          if (count > 1) ...[
            Positioned(
              left: 14,
              top: 0,
              bottom: 0,
              child: Center(child: _SlideButton(icon: Icons.chevron_left, onTap: () => _step(-1))),
            ),
            Positioned(
              right: 14,
              top: 0,
              bottom: 0,
              child: Center(child: _SlideButton(icon: Icons.chevron_right, onTap: () => _step(1))),
            ),
          ],
        ],
      ),
    );
  }
}

class _SlideButton extends StatelessWidget {
  const _SlideButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC141414),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _SlideCard extends StatefulWidget {
  const _SlideCard({required this.entry, required this.library, required this.onPlay});

  final MediaEntry entry;
  final UserLibrary library;
  final VoidCallback onPlay;

  @override
  State<_SlideCard> createState() => _SlideCardState();
}

class _SlideCardState extends State<_SlideCard> {
  String? _plot;
  var _asked = false;

  @override
  void initState() {
    super.initState();
    _plot = shortPlot(widget.entry.plot);
    if (_plot == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (_asked) {
      return;
    }
    _asked = true;
    final source = widget.library.sourceById(widget.entry.sourceId);
    if (source == null) {
      return;
    }
    try {
      final brief = await widget.library.loader.describe(source, widget.entry);
      if (mounted) {
        setState(() => _plot = shortPlot(brief.plot));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final art = entry.backdrop ?? entry.artwork;
    final meta = _metaLine(entry);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF181818)),
          if (art == null)
            TypographicPoster(title: entry.title)
          else
            CoverImage(
              url: art,
              cacheWidth: wide ? 2000 : 1000,
              alignment: const Alignment(0.72, -0.05),
              fallback: TypographicPoster(title: entry.title),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xD9141414), Color(0x40141414), Color(0x00141414)],
                stops: [0, 0.18, 0.42],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x00141414), Color(0xF0141414)],
                stops: [0.72, 0.88, 1],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(wide ? 56 : 20, 24, wide ? 48 : 16, wide ? 36 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _billboardTitle(entry),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MiaType.outfit(wide ? 58 : 34, 700, height: 0.98, letterSpacing: -1.4, color: Colors.white).copyWith(
                          shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 18, offset: Offset(0, 2))],
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MiaType.manrope(wide ? 15 : 13, 500, color: const Color(0xFFF5F5F5)),
                        ),
                      ],
                      if (_plot != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _plot!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MiaType.manrope(wide ? 16 : 13, 400, height: 1.35, color: const Color(0xFFE5E5E5)),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              minimumSize: Size(0, wide ? 44 : 38),
                              padding: EdgeInsets.symmetric(horizontal: wide ? 22 : 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            onPressed: widget.onPlay,
                            icon: const Icon(Icons.play_arrow, size: 28),
                            label: Text('Oynat', style: MiaType.manrope(16, 700, color: Colors.black)),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xB36D6D6E),
                              foregroundColor: Colors.white,
                              minimumSize: Size(0, wide ? 44 : 38),
                              padding: EdgeInsets.symmetric(horizontal: wide ? 20 : 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            onPressed: widget.onPlay,
                            icon: const Icon(Icons.info_outline, size: 22),
                            label: Text('Daha Fazla Bilgi', style: MiaType.manrope(16, 700, color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _billboardTitle(MediaEntry entry) {
  var title = entry.title.trim();
  title = title.replaceAll(RegExp(r'\s*(?:\|[A-Za-z]{2,3}\||\[[A-Za-z]{2,3}\]|\([A-Za-z]{2,3}\))'), '');
  title = title.replaceAll(RegExp(r'\s*\(\d{4}\)'), '');
  final year = entry.year?.trim();
  if (year != null && year.isNotEmpty) {
    title = title.replaceFirst(RegExp('\\s+$year\$'), '');
  }
  final clean = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  return clean.isEmpty ? entry.title.trim() : clean;
}

String _metaLine(MediaEntry entry) {
  final kind = switch (entry.section) {
    ShellSection.series => 'Dizi',
    ShellSection.movies => 'Film',
    ShellSection.live => 'Canlı',
    _ => null,
  };
  final genres = (entry.genre ?? '')
      .split(RegExp(r'[,/|·]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .take(3);
  final year = entry.year?.trim();
  final rating = entry.rating?.trim();
  return [
    ?kind,
    ...genres,
    if (year != null && year.isNotEmpty) year,
    if (entry.minutes != null && entry.minutes! > 0) '${entry.minutes} dk',
    if (rating != null && rating.isNotEmpty) 'IMDb $rating',
    if (voiceLabel(entry) != null) voiceLabel(entry)!,
  ].join('  •  ');
}
