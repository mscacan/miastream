import 'package:flutter/material.dart';

import '../../core/theme.dart';

Color inkFor(String title) {
  final hash = title.codeUnits.fold<int>(0, (sum, unit) => (sum * 33 + unit) & 0xFFFFFF);
  return HSVColor.fromAHSV(1, (hash % 360).toDouble(), 0.5, 0.5).toColor();
}

class TypographicPoster extends StatelessWidget {
  const TypographicPoster({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ink = inkFor(title);
    final trimmed = title.trim();
    final letter = trimmed.isEmpty ? 'M' : trimmed.substring(0, 1).toUpperCase();
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.biggest.shortestSide.isFinite ? box.biggest.shortestSide : 120.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(ink, Colors.white, 0.08)!, Color.lerp(ink, const Color(0xFF0B0B0F), 0.78)!],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                right: -side * 0.12,
                top: -side * 0.18,
                child: Text(
                  letter,
                  style: MiaType.outfit(side * 1.1, 900, height: 1, color: const Color(0x1FFFFFFF)),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(side * 0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: side * 0.14, height: 3, color: const Color(0xFFE50914)),
                    const Spacer(),
                    Text(
                      trimmed,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: MiaType.outfit((side * 0.15).clamp(13.0, 30.0), 750, height: 1.05, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
