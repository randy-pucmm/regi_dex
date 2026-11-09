import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'reduced_motion.dart';

/// Forma de la marca de un indicador: cada estado tiene la suya para no
/// depender solo del color (IND-05).
enum IndicatorGlyph {
  /// ● Todo bien.
  solid,

  /// ○ Apagado, sin conexión.
  hollow,

  /// ◎ Fallo: anillo con un punto.
  target,

  /// ↻ Sincronizando: anillo discontinuo que gira.
  syncing,
}

/// Con «reducir movimiento» el anillo de [IndicatorGlyph.syncing] no gira.
class IndicatorMark extends StatefulWidget {
  const IndicatorMark({
    super.key,
    required this.glyph,
    required this.color,
    this.size = 10,
  });

  final IndicatorGlyph glyph;
  final Color color;
  final double size;

  @override
  State<IndicatorMark> createState() => _IndicatorMarkState();
}

class _IndicatorMarkState extends State<IndicatorMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSpin();
  }

  @override
  void didUpdateWidget(IndicatorMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  void _syncSpin() {
    final shouldSpin =
        widget.glyph == IndicatorGlyph.syncing && !reducedMotion(context);
    if (shouldSpin && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!shouldSpin && _spin.isAnimating) {
      _spin
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RotationTransition(
        turns: _spin,
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _MarkPainter(widget.glyph, widget.color),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.glyph, this.color);

  final IndicatorGlyph glyph;
  final Color color;

  static const _dashes = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final stroke = size.shortestSide / 5;
    final ring = outer - stroke / 2;
    final fill = Paint()..color = color;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    switch (glyph) {
      case IndicatorGlyph.solid:
        canvas.drawCircle(center, outer, fill);
      case IndicatorGlyph.hollow:
        canvas.drawCircle(center, ring, line);
      case IndicatorGlyph.target:
        canvas
          ..drawCircle(center, ring, line)
          ..drawCircle(center, outer * .34, fill);
      case IndicatorGlyph.syncing:
        const step = 2 * math.pi / _dashes;
        final bounds = Rect.fromCircle(center: center, radius: ring);
        for (var i = 0; i < _dashes; i++) {
          canvas.drawArc(bounds, i * step, step * .55, false, line);
        }
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.glyph != glyph || old.color != color;
}
