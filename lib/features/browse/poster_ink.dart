import 'package:flutter/material.dart';

import '../../core/theme.dart';

Color inkFor(String title) {
  final hash = title.codeUnits.fold<int>(0, (sum, unit) => (sum * 33 + unit) & 0xFFFFFF);
  return HSVColor.fromAHSV(1, (hash % 360).toDouble(), 0.42, 0.62).toColor();
}

class TypographicPoster extends StatelessWidget {
  const TypographicPoster({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ink = inkFor(title);
    final trimmed = title.trim();
    final letter = trimmed.isEmpty ? 'M' : trimmed.substring(0, 1).toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ink, Color.lerp(ink, Colors.black, 0.62)!],
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: MiaType.outfit(72, 700, color: Colors.white),
        ),
      ),
    );
  }
}
