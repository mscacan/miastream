import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/device.dart';
import '../../core/theme.dart';
import '../../core/tv_pager.dart';
import '../assist/library_mind.dart';
import '../library/user_library.dart';
import '../playback/media_entry.dart';
import '../shell/shell_section.dart';
import 'cover_store.dart';
import 'mia_rail.dart';
import 'poster_ink.dart';

const _slideSpan = Duration(seconds: 8);
const _ground = Color(0xFF0B0B0F);

class FeaturedSlide extends StatefulWidget {
  const FeaturedSlide({
    super.key,
    required this.entries,
    required this.library,
    required this.onPlay,
    this.billboard = false,
    this.fullBleed = false,
  });

  final List<MediaEntry> entries;
  final UserLibrary library;
  final ValueChanged<MediaEntry> onPlay;
  final bool billboard;

  /// Ana sayfadaki gibi kenardan kenara, üst barın altına uzanan vitrin.
  final bool fullBleed;

  @override
  State<FeaturedSlide> createState() => _FeaturedSlideState();
}

class _FeaturedSlideState extends State<FeaturedSlide> {
  final _pages = PageController();
  Timer? _timer;
  var _index = 0;
  var _held = false;

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
    if (widget.entries.length < 2 || _held) {
      return;
    }
    _timer = Timer.periodic(_slideSpan, (_) => _step(1));
  }

  void _hold(bool focused) {
    _held = focused;
    _arm();
    setState(() {});
  }

  Future<bool> _step(int delta) async {
    final count = widget.entries.length;
    if (!mounted || count < 2) {
      return false;
    }
    var next = (_index + delta) % count;
    if (next < 0) {
      next += count;
    }
    await _pages.animateToPage(next, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
    return true;
  }

  void _jump(int index) {
    _pages.animateToPage(index, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 800;
    final phone = size.width < 600;
    final count = widget.entries.length;
    final double height;
    if (widget.fullBleed) {
      height = phone ? (size.height * 0.74).clamp(470.0, 700.0) : (size.height * 0.86).clamp(480.0, 940.0);
    } else {
      final span = size.width - (wide ? 96 : 32);
      height = wide ? (span / 2.35).clamp(440.0, 560.0) : 430.0;
    }
    final slides = TvPager(
      onStep: _step,
      onFocusChange: _hold,
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
              return ExcludeFocus(
                excluding: index != _index,
                child: _SlideCard(
                  entry: entry,
                  library: widget.library,
                  active: index == _index,
                  fullBleed: widget.fullBleed,
                  onPlay: () => widget.onPlay(entry),
                ),
              );
            },
          ),
          if (count > 1)
            Positioned(
              left: phone && widget.fullBleed ? 0 : null,
              right: phone && widget.fullBleed ? 0 : (widget.fullBleed && wide ? 60 : 24),
              bottom: widget.fullBleed ? (phone ? 10 : 120) : 22,
              child: Center(
                child: _Dots(
                  count: count,
                  index: _index,
                  running: !_held,
                  onTap: MiaDevice.isTv ? null : _jump,
                ),
              ),
            ),
          if (count > 1 && wide && !MiaDevice.isTv) ...[
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Center(child: _SlideButton(icon: Icons.chevron_left, onTap: () => _step(-1))),
            ),
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(child: _SlideButton(icon: Icons.chevron_right, onTap: () => _step(1))),
            ),
          ],
        ],
      ),
    );
    if (widget.fullBleed) {
      return SizedBox(height: height, child: slides);
    }
    return SizedBox(
      height: height,
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: slides),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, required this.running, required this.onTap});

  final int count;
  final int index;
  final bool running;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          GestureDetector(
            onTap: onTap == null ? null : () => onTap!(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: i == index ? 34 : 14,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x55FFFFFF),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: i == index
                    ? TweenAnimationBuilder<double>(
                        key: ValueKey('$index-$running'),
                        tween: Tween(begin: 0, end: 1),
                        duration: running ? _slideSpan : Duration.zero,
                        builder: (context, value, _) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: running ? value : 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _SlideButton extends StatefulWidget {
  const _SlideButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_SlideButton> createState() => _SlideButtonState();
}

class _SlideButtonState extends State<_SlideButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedOpacity(
        opacity: _hover ? 1 : 0.45,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: const Color(0x66000000),
          shape: const CircleBorder(side: BorderSide(color: Color(0x33FFFFFF))),
          child: InkWell(
            canRequestFocus: false,
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(widget.icon, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideCard extends StatefulWidget {
  const _SlideCard({
    required this.entry,
    required this.library,
    required this.active,
    required this.fullBleed,
    required this.onPlay,
  });

  final MediaEntry entry;
  final UserLibrary library;
  final bool active;
  final bool fullBleed;
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
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 800;
    final phone = size.width < 600;
    final live = entry.section == ShellSection.live;
    final backdrop = live ? null : entry.backdrop;
    final art = entry.artwork;
    final tv = MiaDevice.isTv;
    final gutter = widget.fullBleed ? (size.width >= 1400 ? 60.0 : (wide ? 48.0 : 20.0)) : (wide ? 48.0 : 20.0);
    final centered = widget.fullBleed && phone;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _ground),
        if (backdrop != null)
          _KenBurns(
            active: widget.active && !tv,
            child: CoverImage(
              url: backdrop,
              cacheWidth: tv ? 1280 : (wide ? 1920 : 900),
              alignment: const Alignment(0.6, -0.2),
              fallback: TypographicPoster(title: entry.title),
            ),
          )
        else if (art != null) ...[
          Opacity(
            opacity: live ? 0.35 : 0.5,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42, tileMode: TileMode.decal),
              child: CoverImage(url: art, cacheWidth: 200, fallback: const SizedBox.shrink()),
            ),
          ),
          if (centered && !live)
            _KenBurns(
              active: widget.active && !tv,
              child: CoverImage(url: art, cacheWidth: 900, alignment: const Alignment(0, -0.4)),
            )
          else
            Align(
              alignment: centered ? const Alignment(0, -0.45) : const Alignment(0.78, -0.1),
              child: _Showcase(
                art: art,
                title: entry.title,
                live: live,
                height: size.height * (widget.fullBleed ? (centered ? 0.26 : 0.5) : 0.34),
              ),
            ),
        ] else
          TypographicPoster(title: entry.title),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: centered
                  ? const [Color(0x00000000), Color(0x00000000)]
                  : const [Color(0xF00B0B0F), Color(0xA60B0B0F), Color(0x200B0B0F), Color(0x000B0B0F)],
              stops: centered ? const [0, 1] : const [0, 0.3, 0.6, 0.85],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [Color(0x990B0B0F), Color(0x000B0B0F), Color(0x000B0B0F), Color(0xCC0B0B0F), _ground],
              stops: centered ? const [0, 0.18, 0.38, 0.72, 1] : const [0, 0.2, 0.55, 0.86, 1],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            gutter,
            24,
            gutter,
            widget.fullBleed ? (phone ? 44 : (size.height * 0.12).clamp(70.0, 150.0)) : 30,
          ),
          child: Column(
            crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: centered ? double.infinity : (wide ? 620 : 520)),
                child: Column(
                  crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  children: [
                    _KindTag(entry: entry),
                    SizedBox(height: wide ? 14 : 10),
                    Text(
                      _billboardTitle(entry),
                      maxLines: 2,
                      textAlign: centered ? TextAlign.center : TextAlign.start,
                      overflow: TextOverflow.ellipsis,
                      style: MiaType.outfit(
                        widget.fullBleed ? (wide ? (size.width >= 1400 ? 76 : 64) : 40) : (wide ? 52 : 32),
                        800,
                        height: 0.95,
                        letterSpacing: wide ? -2 : -1,
                        color: Colors.white,
                      ).copyWith(shadows: const [Shadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 4))]),
                    ),
                    SizedBox(height: wide ? 16 : 12),
                    _MetaRow(entry: entry, centered: centered),
                    if (_plot != null && !centered) ...[
                      const SizedBox(height: 14),
                      Text(
                        _plot!,
                        maxLines: wide ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: MiaType.manrope(wide ? 17 : 14, 500, height: 1.45, color: const Color(0xFFDCDCE2))
                            .copyWith(shadows: const [Shadow(color: Color(0x99000000), blurRadius: 10)]),
                      ),
                    ],
                    SizedBox(height: wide ? 26 : 20),
                    _Actions(onPlay: widget.onPlay, wide: wide, centered: centered),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KenBurns extends StatelessWidget {
  const _KenBurns({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: active ? 1.07 : 1),
      duration: active ? const Duration(seconds: 12) : const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}

/// Yatay görseli olmayan başlıklarda afişi ya da kanal logosunu sahnede gösterir.
class _Showcase extends StatelessWidget {
  const _Showcase({required this.art, required this.title, required this.live, required this.height});

  final String art;
  final String title;
  final bool live;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (live) {
      return Container(
        width: height * 1.5,
        height: height,
        padding: EdgeInsets.all(height * 0.14),
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
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0xCC000000), blurRadius: 50, offset: Offset(0, 24))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CoverImage(url: art, cacheWidth: 720, fallback: TypographicPoster(title: title)),
      ),
    );
  }
}

class _KindTag extends StatelessWidget {
  const _KindTag({required this.entry});

  final MediaEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.section == ShellSection.live) {
      final group = entry.group.trim();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LiveBadge(big: true),
          if (group.isNotEmpty && group != 'Canlı') ...[
            const SizedBox(width: 10),
            Text(group.toUpperCase(),
                style: MiaType.manrope(12, 700, color: const Color(0xFFCFCFD6)).copyWith(letterSpacing: 2)),
          ],
        ],
      );
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.entry, required this.centered});

  final MediaEntry entry;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final rating = entry.rating?.trim();
    final year = entry.year?.trim();
    final genres = (entry.genre ?? '')
        .split(RegExp(r'[,/|·]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .take(centered ? 2 : 3)
        .toList();
    final voice = voiceLabel(entry);
    final soft = MiaType.manrope(14, 600, color: const Color(0xFFD6D6DC));
    final bits = <Widget>[
      if (rating != null && rating.isNotEmpty)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFC53D)),
            const SizedBox(width: 3),
            Text(rating, style: MiaType.manrope(14, 800, color: Colors.white)),
          ],
        ),
      if (year != null && year.isNotEmpty) Text(year, style: soft),
      if (entry.minutes != null && entry.minutes! > 0) Text(_duration(entry.minutes!), style: soft),
      if (entry.section != ShellSection.live) const _Chip(text: 'HD'),
      if (voice != null) _Chip(text: voice),
      for (final genre in genres) Text(genre, style: soft),
    ];
    if (bits.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      alignment: centered ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: bits,
    );
  }
}

String _duration(int minutes) {
  if (minutes < 60) {
    return '$minutes dk';
  }
  final rest = minutes % 60;
  return rest == 0 ? '${minutes ~/ 60} sa' : '${minutes ~/ 60} sa $rest dk';
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

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

class _Actions extends StatelessWidget {
  const _Actions({required this.onPlay, required this.wide, required this.centered});

  final VoidCallback onPlay;
  final bool wide;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final height = wide ? 52.0 : 44.0;
    final play = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        minimumSize: Size(0, height),
        padding: EdgeInsets.symmetric(horizontal: wide ? 30 : 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ).copyWith(side: MiaTheme.lightFocusRing),
      onPressed: onPlay,
      icon: Icon(Icons.play_arrow_rounded, size: wide ? 34 : 28),
      label: Text('Oynat', style: MiaType.manrope(wide ? 18 : 16, 800, color: Colors.black)),
    );
    final more = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0x4DFFFFFF),
            foregroundColor: Colors.white,
            minimumSize: Size(0, height),
            padding: EdgeInsets.symmetric(horizontal: wide ? 26 : 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: onPlay,
          icon: Icon(Icons.info_outline_rounded, size: wide ? 26 : 22),
          label: Text(wide ? 'Daha Fazla Bilgi' : 'Bilgi', style: MiaType.manrope(wide ? 18 : 16, 700, color: Colors.white)),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [play, const SizedBox(width: 12), more],
    );
  }
}

String _billboardTitle(MediaEntry entry) {
  var title = entry.title.trim();
  title = title.replaceAll(RegExp(r'\s*(?:\|[A-Za-z]{2,3}\||\[[A-Za-z]{2,3}\]|\([A-Za-z]{2,3}\))'), '');
  title = title.replaceAll(RegExp(r'\s*\(\d{4}\)'), '');
  title = title.replaceAll(RegExp(r'\s*\((?:\d{3,4}p|HD|FHD|UHD|4K)\)', caseSensitive: false), '');
  title = title.replaceAll(RegExp(r'\s*\[[^\]]*\]'), '');
  final year = entry.year?.trim();
  if (year != null && year.isNotEmpty) {
    title = title.replaceFirst(RegExp('\\s+$year\$'), '');
  }
  final clean = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  return clean.isEmpty ? entry.title.trim() : clean;
}
