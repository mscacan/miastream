import 'package:flutter/material.dart';

import '../../core/brand.dart';
import '../../core/theme.dart';

/// Kayıtlı kaynak yokken açılan ekran. Tek eylem kaynak eklemektir.
class SourceEntry extends StatelessWidget {
  const SourceEntry({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final mia = context.mia;
    return Scaffold(
      backgroundColor: mia.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: const Alignment(0, -0.42),
            child: const _Glow(),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  Brand.name,
                  textAlign: TextAlign.center,
                  style: MiaType.outfit(52, 650, letterSpacing: -1.1, height: 1, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  Brand.storeSubtitle,
                  textAlign: TextAlign.center,
                  style: MiaType.manrope(18, 500, color: mia.muted),
                ),
                const SizedBox(height: 36),
                FilledButton(
                  onPressed: onAdd,
                  child: const Text('Kaynak Ekle'),
                ),
              ],
            ),
          ),
          Positioned(
            left: 32,
            right: 32,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: Text(
                'Bu, sıradan bir kişisel medya oynatıcıdır. Yayın satışı yoktur. '
                'Kaynağı sen eklersin; izlediğin içeriğin sorumluluğu da sana aittir.',
                textAlign: TextAlign.center,
                style: MiaType.manrope(13, 500, color: mia.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    final mia = context.mia;
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [mia.glow, mia.background.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
