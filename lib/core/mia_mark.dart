import 'package:flutter/material.dart';

import 'theme.dart';

/// Uygulama işareti. Kırmızı, Netflix logosunun kırmızısı.
const miaRed = Color(0xFFE50914);

class MiaWord extends StatelessWidget {
  const MiaWord({super.key, this.size = 22, this.compact = false});

  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text(
      compact ? 'Mia' : 'Mia Stream',
      style: MiaType.quicksand(size, 700, height: 1, letterSpacing: -0.2, color: miaRed),
    );
  }
}
