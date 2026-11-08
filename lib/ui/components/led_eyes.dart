import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../themes/regi_theme.dart';
import '../tokens/led_state.dart';
import '../tokens/regi_colors.dart';
import '../tokens/regi_palette.dart';
import 'reduced_motion.dart';

/// Cada estado anima de forma distinta a cada grupo de ojos.
enum EyeGroup { outer, middle, center }

@immutable
class EyePose {
  const EyePose({required this.lit, this.glow = 2.5, this.rimAlpha = .5});

  /// De 0 (apagado) a 1 (encendido).
  final double lit;
  final double glow;
  final double rimAlpha;
}

enum _Motion { breath, blip, standby, two, one, half, steady }

class _Spec {
  const _Spec(this.lit, this.motion, this.seconds, [this.delay = 0]);

  /// Encendido sin animación (movimiento reducido).
  final bool lit;
  final _Motion motion;
  final double seconds;
  final double delay;
}

/// Según el diseño «Lenguaje de los ojos».
_Spec _specOf(LedState state, EyeGroup group, int index) {
  return switch (state) {
    LedState.online => switch (group) {
      EyeGroup.outer ||
      EyeGroup.center => const _Spec(true, _Motion.breath, 3.2),
      EyeGroup.middle => const _Spec(false, _Motion.blip, 4.2),
    },
    LedState.offline => _Spec(false, _Motion.standby, 4, index * .5),
    LedState.down => switch (group) {
      EyeGroup.outer => const _Spec(true, _Motion.two, 2.4),
      EyeGroup.middle => const _Spec(true, _Motion.two, 2.4, -1.6),
      EyeGroup.center => const _Spec(false, _Motion.one, 2.4),
    },
    LedState.sync => switch (group) {
      EyeGroup.outer => const _Spec(true, _Motion.half, 1.6),
      EyeGroup.middle => const _Spec(true, _Motion.half, 1.6, -.8),
      EyeGroup.center => const _Spec(true, _Motion.steady, 0),
    },
  };
}

/// Interpola con «ease-in-out» entre fotogramas clave, como el diseño.
double _interpolate(double phase, List<(double, double)> keys) {
  for (var i = 1; i < keys.length; i++) {
    if (phase <= keys[i].$1) {
      final (p0, v0) = keys[i - 1];
      final (p1, v1) = keys[i];
      if (p1 == p0) return v1;
      final t = Curves.easeInOut.transform((phase - p0) / (p1 - p0));
      return v0 + (v1 - v0) * t;
    }
  }
  return keys.last.$2;
}

const _pulse = [(0.0, 0.0), (.5, 1.0), (1.0, 0.0)];
const _blip = [
  (0.0, 0.0),
  (.64, 0.0),
  (.68, 1.0),
  (.76, 1.0),
  (.80, 0.0),
  (.84, 0.0),
  (.88, 1.0),
  (.94, 1.0),
  (.98, 0.0),
  (1.0, 0.0),
];
const _two = [(0.0, 1.0), (.6, 1.0), (.7, 0.0), (.92, 0.0), (1.0, 1.0)];
const _one = [(0.0, 1.0), (.24, 1.0), (.34, 0.0), (.92, 0.0), (1.0, 1.0)];
const _half = [(0.0, 1.0), (.38, 1.0), (.5, 0.0), (.88, 0.0), (1.0, 1.0)];

/// Con [animate] en falso (movimiento reducido) devuelve la pose fija.
EyePose eyePose({
  required LedState state,
  required EyeGroup group,
  required int index,
  required double seconds,
  bool animate = true,
}) {
  final spec = _specOf(state, group, index);
  if (!animate || spec.motion == _Motion.steady) {
    return EyePose(lit: spec.lit ? 1 : 0);
  }
  final cycles = (seconds - spec.delay) / spec.seconds;
  final phase = cycles - cycles.floorToDouble();
  return switch (spec.motion) {
    _Motion.breath => EyePose(
      lit: 1,
      glow: lerpDouble(1.2, 4, _interpolate(phase, _pulse))!,
    ),
    _Motion.blip => EyePose(lit: _interpolate(phase, _blip)),
    _Motion.standby => EyePose(
      lit: 0,
      rimAlpha: lerpDouble(.2, .65, _interpolate(phase, _pulse))!,
    ),
    _Motion.two => EyePose(lit: _interpolate(phase, _two)),
    _Motion.one => EyePose(lit: _interpolate(phase, _one)),
    _Motion.half => EyePose(lit: _interpolate(phase, _half)),
    _Motion.steady => const EyePose(lit: 1),
  };
}

class _Eye {
  const _Eye.outer(this.x, this.y) : group = EyeGroup.outer;
  const _Eye.middle(this.x, this.y) : group = EyeGroup.middle;
  const _Eye.center(this.x, this.y) : group = EyeGroup.center;

  final double x;
  final double y;
  final EyeGroup group;
}

/// Disposición de los puntos de cada Regi sobre un lienzo de 40 × 40.
const _patterns = <RegiVariant, List<_Eye>>{
  RegiVariant.regirock: [
    _Eye.outer(10, 9),
    _Eye.middle(10, 20),
    _Eye.outer(10, 31),
    _Eye.outer(30, 9),
    _Eye.middle(30, 20),
    _Eye.outer(30, 31),
    _Eye.center(20, 20),
  ],
  RegiVariant.regice: [
    _Eye.outer(20, 8),
    _Eye.middle(9, 20),
    _Eye.middle(31, 20),
    _Eye.outer(20, 32),
    _Eye.center(20, 20),
  ],
  RegiVariant.registeel: [
    _Eye.outer(31, 20),
    _Eye.middle(25.5, 29.5),
    _Eye.outer(14.5, 29.5),
    _Eye.middle(9, 20),
    _Eye.outer(14.5, 10.5),
    _Eye.middle(25.5, 10.5),
  ],
  RegiVariant.regigigas: [
    _Eye.outer(13, 9),
    _Eye.outer(27, 9),
    _Eye.middle(13, 20),
    _Eye.middle(27, 20),
    _Eye.outer(13, 31),
    _Eye.outer(27, 31),
  ],
  RegiVariant.regieleki: [
    _Eye.outer(5, 13),
    _Eye.outer(5, 27),
    _Eye.outer(35, 13),
    _Eye.outer(35, 27),
    _Eye.middle(14, 20),
    _Eye.middle(26, 20),
  ],
  RegiVariant.regidrago: [
    _Eye.outer(9, 12),
    _Eye.middle(20, 12),
    _Eye.outer(31, 12),
    _Eye.middle(14.5, 22),
    _Eye.middle(25.5, 22),
    _Eye.outer(20, 32),
  ],
};

/// Los ojos LED de un Regi, que se encienden y apagan según [state].
/// Es decorativo (no se anuncia) y con «reducir movimiento» no anima.
class LedEyes extends StatefulWidget {
  const LedEyes({super.key, required this.state, this.size = 48, this.variant});

  final LedState state;
  final double size;

  /// Por defecto, el Regi del tema.
  final RegiVariant? variant;

  @override
  State<LedEyes> createState() => _LedEyesState();
}

class _LedEyesState extends State<LedEyes> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _seconds = ValueNotifier<double>(0);
  var _animate = true;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _seconds.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = !reducedMotion(context);
    if (_animate && !_ticker.isActive) {
      _ticker.start();
    } else if (!_animate && _ticker.isActive) {
      _ticker.stop();
      _seconds.value = 0;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _EyesPainter(
            seconds: _seconds,
            eyes: _patterns[widget.variant ?? regi.variant]!,
            state: widget.state,
            on: regi.ledColor(widget.state),
            animate: _animate,
          ),
        ),
      ),
    );
  }
}

class _EyesPainter extends CustomPainter {
  _EyesPainter({
    required this.seconds,
    required this.eyes,
    required this.state,
    required this.on,
    required this.animate,
  }) : super(repaint: seconds);

  final ValueListenable<double> seconds;
  final List<_Eye> eyes;
  final LedState state;
  final Color on;
  final bool animate;

  // Lienzo del diseño: 52 unidades, con 6 de margen alrededor de los 40 de datos.
  static const _canvas = 52.0;
  static const _margin = 6.0;
  static const _radius = 3.7;
  static const _stroke = 1.3;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..scale(size.shortestSide / _canvas)
      ..translate(_margin, _margin);

    for (final (index, eye) in eyes.indexed) {
      final pose = eyePose(
        state: state,
        group: eye.group,
        index: index,
        seconds: seconds.value,
        animate: animate,
      );
      final center = Offset(eye.x, eye.y);

      if (pose.lit > 0) {
        // El halo es algo mayor que el punto para que no lo tape.
        canvas.drawCircle(
          center,
          _radius + .9,
          Paint()
            ..color = on.withValues(alpha: pose.lit * .9)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, pose.glow * .6),
        );
      }
      canvas
        ..drawCircle(
          center,
          _radius,
          Paint()..color = Color.lerp(RegiLedColors.off, on, pose.lit)!,
        )
        ..drawCircle(
          center,
          _radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _stroke
            ..color = Color.lerp(
              Colors.white.withValues(alpha: pose.rimAlpha),
              on,
              pose.lit,
            )!,
        );
    }
  }

  @override
  bool shouldRepaint(_EyesPainter old) =>
      old.state != state ||
      old.on != on ||
      old.animate != animate ||
      !identical(old.eyes, eyes);
}
