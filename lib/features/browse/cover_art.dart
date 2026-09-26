import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'cover_store.dart';
import 'poster_ink.dart';

class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.title,
    this.artwork,
    this.onTap,
    this.width = 132,
    this.contain = false,
    this.inset = 18,
    this.add = false,
    this.titleBelow = false,
    this.note,
    this.progress,
  });

  final String title;
  final String? artwork;
  final VoidCallback? onTap;
  final double width;
  final bool contain;
  final double inset;
  final bool add;
  final bool titleBelow;
  final String? note;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final mia = context.mia;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: mia.card),
          if (artwork == null && !add) TypographicPoster(title: title),
          if (artwork != null)
            Padding(
              padding: EdgeInsets.all(contain ? inset : 0),
              child: CoverImage(
                url: artwork!,
                fit: contain ? BoxFit.contain : BoxFit.cover,
                fallback: TypographicPoster(title: title),
              ),
            ),
          if (!titleBelow)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xE6000000)],
                  stops: [0.45, 1],
                ),
              ),
            ),
          if (!titleBelow && progress != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: progress!.clamp(0, 1).toDouble(),
                minHeight: 3,
                color: const Color(0xFFE50914),
                backgroundColor: const Color(0x66FFFFFF),
              ),
            ),
          if (!titleBelow)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (add) const Icon(Icons.add, color: Colors.white, size: 32),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MiaType.manrope(14, 700, color: Colors.white),
                  ),
                  if (note != null && note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MiaType.manrope(11, 600, color: const Color(0xFFE5E5E5)),
                    ),
                  ],
                ],
              ),
            )
          else if (add)
            const Center(child: Icon(Icons.add, color: Colors.white, size: 32)),
        ],
      ),
    );
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(4),
                child: image,
              ),
            ),
          ),
          if (titleBelow) ...[
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MiaType.manrope(13, 600, color: const Color(0xFFE5E5E5)),
            ),
            if (note != null && note!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MiaType.manrope(11, 600, color: const Color(0xFFB3B3B3)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class ArtworkThumb extends StatelessWidget {
  const ArtworkThumb({super.key, this.artwork, this.width = 72, this.height = 104});

  final String? artwork;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(
          color: context.mia.card,
          child: artwork == null
              ? Icon(Icons.movie_outlined, color: context.mia.muted)
              : CoverImage(
                  url: artwork!,
                  fallback: Icon(Icons.movie_outlined, color: context.mia.muted),
                ),
        ),
      ),
    );
  }
}
