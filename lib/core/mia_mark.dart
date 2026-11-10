import 'package:flutter/material.dart';

import 'theme.dart';

/// Uygulama işareti. Kırmızı, Netflix logosunun kırmızısı.
const miaRed = Color(0xFFE50914);

const _redTop = Color(0xFFFF3B4A);
const _redBottom = Color(0xFFC40012);

/// MIA kelimesi. A harfinin içindeki üçgen oynat düğmesidir.
/// Geometri tool/brand/make_brand.py ile aynıdır; harf yüksekliği 100 birim.
class MiaWord extends StatelessWidget {
  const MiaWord({super.key, this.size = 22, this.compact = false});

  /// Harf yüksekliği.
  final double size;

  /// true ise yalnız MIA, değilse altında STREAM yazar.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = size * _wordWidth / 100;
    final word = SizedBox(
      width: width,
      height: size,
      child: const CustomPaint(painter: _MiaPainter()),
    );
    if (compact) {
      return Semantics(label: 'Mia Stream', child: word);
    }
    return Semantics(
      label: 'Mia Stream',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            word,
            SizedBox(height: size * 0.16),
            SizedBox(
              width: width,
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: Text(
                  'S T R E A M',
                  style: MiaType.outfit(20, 600, height: 1, letterSpacing: 6, color: const Color(0xFFBEBEC4)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _wordWidth = 292.0;

const _m = [
  Offset(0, 100), Offset(0, 0), Offset(24, 0), Offset(58, 48), Offset(92, 0), Offset(116, 0), Offset(116, 100),
  Offset(92, 100), Offset(92, 40), Offset(64, 80), Offset(52, 80), Offset(24, 40), Offset(24, 100),
];
const _i = [Offset(132, 0), Offset(156, 0), Offset(156, 100), Offset(132, 100)];
const _aOut = [Offset(172, 100), Offset(222, 0), Offset(242, 0), Offset(292, 100)];
const _aIn = [Offset(199, 100), Offset(232, 34), Offset(265, 100)];
const _play = [Offset(225, 69), Offset(225, 97), Offset(249, 83)];

class _MiaPainter extends CustomPainter {
  const _MiaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.height / 100;
    Path shape(List<Offset> points) => Path()..addPolygon([for (final p in points) p * k], true);

    final white = Paint()..color = Colors.white;
    canvas.drawPath(shape(_m), white);
    canvas.drawPath(shape(_i), white);

    final a = Path.combine(PathOperation.difference, shape(_aOut), shape(_aIn));
    final red = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_redTop, _redBottom],
      ).createShader(Offset.zero & size);
    canvas.drawPath(a, red);
    canvas.drawPath(shape(_play), white);
  }

  @override
  bool shouldRepaint(_MiaPainter oldDelegate) => false;
}
