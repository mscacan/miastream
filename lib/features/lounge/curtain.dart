import 'package:flutter/material.dart';

import '../../core/theme.dart';

class Curtain extends StatefulWidget {
  const Curtain({super.key, required this.onPick});

  final ValueChanged<String> onPick;

  @override
  State<Curtain> createState() => _CurtainState();
}

class _CurtainState extends State<Curtain> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
      child: Material(
        color: Colors.black,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Mia Stream',
                    style: MiaType.outfit(18, 600, letterSpacing: 3, color: Colors.white54),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'İki koltuk',
                    style: MiaType.outfit(42, 700, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aynı kaynak. Ayrı kaldığın yer.',
                    style: MiaType.manrope(15, 500, color: Colors.white60),
                  ),
                  const SizedBox(height: 36),
                  if (MediaQuery.sizeOf(context).width < 520)
                    Column(
                      children: [
                        _SeatName(name: 'Miran', onTap: () => widget.onPick('miran')),
                        const SizedBox(height: 8),
                        _SeatName(name: 'Asmin', onTap: () => widget.onPick('asmin')),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SeatName(name: 'Miran', onTap: () => widget.onPick('miran')),
                        Container(width: 1, height: 72, color: Colors.white24),
                        _SeatName(name: 'Asmin', onTap: () => widget.onPick('asmin')),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatName extends StatelessWidget {
  const _SeatName({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        child: Text(name, style: MiaType.outfit(36, 650, color: Colors.white)),
      ),
    );
  }
}
