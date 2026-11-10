import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kaydırmalı vitrinlerde kumanda desteği.
///
/// Sol/sağ tuşu sayfanın içinde gidecek yer bulamazsa sayfayı çevirir ve
/// odağı yeni sayfanın ilk düğmesine taşır. İçeride odak varken [onFocusChange]
/// true döner; otomatik geçiş bu sürede durdurulmalıdır, yoksa odak kaybolur.
class TvPager extends StatefulWidget {
  const TvPager({super.key, required this.child, required this.onStep, this.onFocusChange});

  final Widget child;

  /// Sayfayı çevirir. Çevrildiyse true döner, animasyon bitince tamamlanır.
  final Future<bool> Function(int delta) onStep;
  final ValueChanged<bool>? onFocusChange;

  @override
  State<TvPager> createState() => _TvPagerState();
}

class _TvPagerState extends State<TvPager> {
  final _node = FocusNode(debugLabel: 'TvPager', skipTraversal: true);

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final delta = key == LogicalKeyboardKey.arrowLeft
        ? -1
        : key == LogicalKeyboardKey.arrowRight
            ? 1
            : 0;
    if (delta == 0) {
      return KeyEventResult.ignored;
    }
    final primary = FocusManager.instance.primaryFocus;
    final next = primary == null || primary == _node ? null : _neighbor(primary, delta);
    if (next != null) {
      next.requestFocus();
      return KeyEventResult.handled;
    }
    _flip(delta);
    return KeyEventResult.handled;
  }

  /// Aynı satırda, verilen yöndeki en yakın odaklanabilir öğe.
  FocusNode? _neighbor(FocusNode from, int delta) {
    final here = from.rect;
    FocusNode? best;
    var bestGap = double.infinity;
    for (final item in _node.traversalDescendants) {
      if (item == from || !item.canRequestFocus) {
        continue;
      }
      final r = item.rect;
      final sameRow = r.top < here.bottom && r.bottom > here.top;
      if (!sameRow || !_node.rect.contains(r.center)) {
        continue;
      }
      final gap = delta > 0 ? r.left - here.right : here.left - r.right;
      if (gap >= -1 && gap < bestGap) {
        bestGap = gap;
        best = item;
      }
    }
    return best;
  }

  Future<void> _flip(int delta) async {
    _node.requestFocus();
    final flipped = await widget.onStep(delta);
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (flipped || _node.hasPrimaryFocus)) {
        _refocus();
      }
    });
  }

  void _refocus() {
    final box = _node.rect;
    final visible = [
      for (final item in _node.traversalDescendants)
        if (item.canRequestFocus && box.contains(item.rect.center)) item,
    ]..sort((a, b) {
        final row = a.rect.top.compareTo(b.rect.top);
        return row != 0 ? row : a.rect.left.compareTo(b.rect.left);
      });
    if (visible.isNotEmpty) {
      visible.first.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      onKeyEvent: _onKey,
      onFocusChange: widget.onFocusChange,
      child: widget.child,
    );
  }
}
