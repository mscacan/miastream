import 'package:flutter/material.dart';

import '../../core/device.dart';
import '../../core/theme.dart';
import 'cover_store.dart';
import 'poster_ink.dart';

/// Ekran genişliğine göre raf ölçüleri.
class RailMetrics {
  RailMetrics._(this.gutter, this.poster, this.wide, this.phone);

  factory RailMetrics.of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final phone = width < 600;
    final gutter = width >= 1400 ? 60.0 : (width >= 800 ? 48.0 : 16.0);
    final visible = width >= 1600
        ? 8.0
        : width >= 1300
            ? 7.0
            : width >= 1000
                ? 6.0
                : width >= 800
                    ? 5.0
                    : width >= 600
                        ? 4.2
                        : 3.15;
    final poster = ((width - gutter * 2 - (visible.ceil() - 1) * 8) / visible).clamp(104.0, 240.0);
    return RailMetrics._(gutter, poster, width >= 800, phone);
  }

  final double gutter;
  final double poster;
  final bool wide;
  final bool phone;

  double get landscape => (poster * 1.62).clamp(150.0, 340.0);
  double get live => (poster * 1.3).clamp(140.0, 280.0);
}

/// Başlıklı yatay raf. Masaüstünde fareyle üzerine gelince kaydırma okları çıkar.
class MiaRail extends StatefulWidget {
  const MiaRail({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    required this.height,
    this.gap = 8,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Kartların yüksekliği; büyüme payı ayrıca eklenir.
  final double height;
  final double gap;

  @override
  State<MiaRail> createState() => _MiaRailState();
}

class _MiaRailState extends State<MiaRail> {
  static const _lift = 18.0;
  final _scroll = ScrollController();
  var _hover = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _page(int direction) {
    if (!_scroll.hasClients) {
      return;
    }
    final position = _scroll.position;
    final target = (position.pixels + direction * position.viewportDimension * 0.82)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = RailMetrics.of(context);
    final arrows = metrics.wide && !MiaDevice.isTv;
    return Padding(
      padding: EdgeInsets.only(bottom: metrics.wide ? 18 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(metrics.gutter, 0, metrics.gutter, 0),
            child: _RailHeader(
              title: widget.title,
              subtitle: widget.subtitle,
              trailing: widget.trailing,
              hover: _hover,
              big: metrics.wide,
            ),
          ),
          MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: SizedBox(
              height: widget.height + _lift * 2,
              child: Stack(
                children: [
                  ListView.separated(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: metrics.gutter, vertical: _lift),
                    itemCount: widget.itemCount,
                    separatorBuilder: (_, _) => SizedBox(width: widget.gap),
                    itemBuilder: widget.itemBuilder,
                  ),
                  if (arrows) ...[
                    _EdgeArrow(
                      left: true,
                      width: metrics.gutter,
                      visible: _hover,
                      controller: _scroll,
                      onTap: () => _page(-1),
                    ),
                    _EdgeArrow(
                      left: false,
                      width: metrics.gutter,
                      visible: _hover,
                      controller: _scroll,
                      onTap: () => _page(1),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.hover,
    required this.big,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool hover;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MiaType.outfit(big ? 23 : 18, 680, letterSpacing: -0.3, color: const Color(0xFFF2F2F5)),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(subtitle!, style: MiaType.manrope(12, 600, color: const Color(0xFF8C8C96))),
          ),
        ],
        if (big)
          AnimatedOpacity(
            opacity: hover ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(left: hover ? 14 : 4, bottom: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tümünü keşfet', style: MiaType.manrope(12, 700, color: const Color(0xFF54B9C5))),
                  const Icon(Icons.chevron_right, size: 16, color: Color(0xFF54B9C5)),
                ],
              ),
            ),
          ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

class _EdgeArrow extends StatelessWidget {
  const _EdgeArrow({
    required this.left,
    required this.width,
    required this.visible,
    required this.controller,
    required this.onTap,
  });

  final bool left;
  final double width;
  final bool visible;
  final ScrollController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left ? 0 : null,
      right: left ? null : 0,
      top: _MiaRailState._lift,
      bottom: _MiaRailState._lift,
      width: width,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final ready = controller.hasClients && controller.position.hasContentDimensions;
          final can = ready &&
              (left
                  ? controller.position.pixels > controller.position.minScrollExtent + 4
                  : controller.position.pixels < controller.position.maxScrollExtent - 4);
          return IgnorePointer(
            ignoring: !(visible && can),
            child: AnimatedOpacity(
              opacity: visible && can ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: const Color(0x99000000),
                borderRadius: BorderRadius.horizontal(
                  left: left ? Radius.zero : const Radius.circular(6),
                  right: left ? const Radius.circular(6) : Radius.zero,
                ),
                child: InkWell(
                  canRequestFocus: false,
                  onTap: onTap,
                  child: Center(
                    child: Icon(left ? Icons.chevron_left : Icons.chevron_right, color: Colors.white, size: 38),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum TileShape { poster, landscape, live }

/// Fareyle ya da kumandayla öne çıkan, gölgeli ve büyüyen kart.
class MiaTile extends StatefulWidget {
  const MiaTile({
    super.key,
    required this.title,
    required this.width,
    this.artwork,
    this.onTap,
    this.shape = TileShape.poster,
    this.note,
    this.progress,
    this.badge,
  });

  final String title;
  final String? artwork;
  final double width;
  final VoidCallback? onTap;
  final TileShape shape;
  final String? note;
  final double? progress;
  final String? badge;

  double get height => switch (shape) {
        TileShape.poster => width * 1.5,
        TileShape.landscape => width * 9 / 16,
        TileShape.live => width * 0.62,
      };

  @override
  State<MiaTile> createState() => _MiaTileState();
}

class _MiaTileState extends State<MiaTile> {
  var _hover = false;
  var _focus = false;

  bool get _lit => _hover || _focus;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.shape == TileShape.poster ? 6 : 8);
    final live = widget.shape == TileShape.live;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedScale(
        scale: _lit ? 1.08 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: _lit ? const Color(0xCC000000) : const Color(0x55000000),
                blurRadius: _lit ? 26 : 10,
                offset: Offset(0, _lit ? 12 : 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onHover: (value) => setState(() => _hover = value),
              onFocusChange: (value) => setState(() => _focus = value),
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              borderRadius: radius,
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (live) const _LiveBackdrop() else const ColoredBox(color: Color(0xFF1B1B21)),
                    if (widget.artwork == null)
                      live ? _LiveName(title: widget.title) : TypographicPoster(title: widget.title)
                    else
                      Padding(
                        padding: live ? EdgeInsets.fromLTRB(widget.width * 0.16, 18, widget.width * 0.16, 26) : EdgeInsets.zero,
                        child: CoverImage(
                          url: widget.artwork!,
                          fit: live ? BoxFit.contain : BoxFit.cover,
                          cacheWidth: live ? 320 : 480,
                          fallback: live ? _LiveName(title: widget.title) : TypographicPoster(title: widget.title),
                        ),
                      ),
                    AnimatedOpacity(
                      opacity: _lit || live || widget.note != null ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0x00000000), Color(0xE6000000)],
                            stops: [0, 0.5, 1],
                          ),
                        ),
                      ),
                    ),
                    if (live) const Positioned(left: 8, top: 8, child: LiveBadge()),
                    if (widget.badge != null)
                      Positioned(right: 0, top: 10, child: _CornerBadge(text: widget.badge!)),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: widget.progress != null ? 12 : 9,
                      child: AnimatedOpacity(
                        opacity: _lit || live || widget.note != null ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_lit && !live) ...[
                              Container(
                                width: 30,
                                height: 30,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              widget.title,
                              maxLines: live ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: MiaType.manrope(live ? 12 : 13, 750, height: 1.2, color: Colors.white),
                            ),
                            if (widget.note != null && widget.note!.isNotEmpty)
                              Text(
                                widget.note!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MiaType.manrope(11, 600, height: 1.3, color: const Color(0xFFBDBDC6)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.progress != null)
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: widget.progress!.clamp(0, 1).toDouble(),
                            minHeight: 3,
                            color: const Color(0xFFE50914),
                            backgroundColor: const Color(0x55FFFFFF),
                          ),
                        ),
                      ),
                    if (_focus)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: radius,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveBackdrop extends StatelessWidget {
  const _LiveBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.1,
          colors: [Color(0xFF2E2E38), Color(0xFF15151B)],
        ),
      ),
    );
  }
}

class _LiveName extends StatelessWidget {
  const _LiveName({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          title,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: MiaType.outfit(18, 700, color: Colors.white),
        ),
      ),
    );
  }
}

class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, this.big = false});

  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 9 : 6, vertical: big ? 4 : 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE50914),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: big ? 7 : 5,
            height: big ? 7 : 5,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
          SizedBox(width: big ? 6 : 4),
          Text(
            'CANLI',
            style: MiaType.manrope(big ? 12 : 9, 800, height: 1.2, color: Colors.white).copyWith(letterSpacing: 1.1),
          ),
        ],
      ),
    );
  }
}

class _CornerBadge extends StatelessWidget {
  const _CornerBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 6, 3),
      decoration: const BoxDecoration(
        color: Color(0xFFE50914),
        borderRadius: BorderRadius.horizontal(left: Radius.circular(3)),
      ),
      child: Text(text, style: MiaType.manrope(10, 800, height: 1.2, color: Colors.white)),
    );
  }
}

/// Top 10 rafı için: dev, içi boş numara ve yanında afiş.
class RankedTile extends StatelessWidget {
  const RankedTile({super.key, required this.rank, required this.tile});

  final int rank;
  final MiaTile tile;

  @override
  Widget build(BuildContext context) {
    final h = tile.height;
    final numberWidth = h * (rank >= 10 ? 0.62 : 0.42);
    return SizedBox(
      width: numberWidth + tile.width * 0.86,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: -h * 0.08,
            child: _RankNumber(rank: rank, size: h * 0.92),
          ),
          Positioned(right: 0, top: 0, bottom: 0, child: tile),
        ],
      ),
    );
  }
}

class _RankNumber extends StatelessWidget {
  const _RankNumber({required this.rank, required this.size});

  final int rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final base = MiaType.outfit(size, 900, height: 1, letterSpacing: rank >= 10 ? -size * 0.12 : 0);
    return Stack(
      children: [
        Text(
          '$rank',
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.035
              ..color = const Color(0xFF8E8E98),
          ),
        ),
        Text('$rank', style: base.copyWith(color: const Color(0xFF0B0B0F))),
      ],
    );
  }
}
