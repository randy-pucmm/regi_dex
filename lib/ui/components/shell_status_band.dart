import 'package:flutter/material.dart';

import '../themes/regi_theme.dart';
import 'hexagon_border.dart';
import 'reduced_motion.dart';

/// Banda hexagonal con el estado (título) y el origen de los datos (subtítulo),
/// con [leading] y [trailing] a los lados. Con [onTap] es un botón.
class ShellStatusBand extends StatelessWidget {
  const ShellStatusBand({
    super.key,
    required this.color,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.progress = false,
  });

  final Color color;
  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Barra fina de avance indeterminado (sincronizando).
  final bool progress;

  static const _pointDepth = 22.0;

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    final text = Theme.of(context).textTheme;
    final shape = HexagonBorder(
      pointAxis: Axis.horizontal,
      depth: _pointDepth,
      side: BorderSide(color: color, width: 2),
    );

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _pointDepth + 4,
        vertical: 8,
      ),
      child: Row(
        children: [
          ?leading,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: text.titleMedium?.copyWith(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(color: regi.onShell),
                  ),
                  if (progress)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 170),
                        child: SizedBox(
                          height: 6,
                          width: double.infinity,
                          child: ExcludeSemantics(
                            child: _SyncBar(color: color),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );

    return Semantics(
      container: true,
      button: onTap != null,
      label: '$title. $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: regi.shell,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(onTap: onTap, customBorder: shape, child: content),
      ),
    );
  }
}

/// Barra con puntas en flecha y un tramo que la recorre; con «reducir
/// movimiento» el tramo queda fijo.
class _SyncBar extends StatefulWidget {
  const _SyncBar({required this.color});

  final Color color;

  @override
  State<_SyncBar> createState() => _SyncBarState();
}

class _SyncBarState extends State<_SyncBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SyncBarPainter(progress: _controller, color: widget.color),
    );
  }
}

class _SyncBarPainter extends CustomPainter {
  _SyncBarPainter({required this.progress, required this.color})
    : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  static const _segment = .46;
  static const _track = Color(0xFF2A3033);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final outline = Path()
      ..moveTo(0, h / 2)
      ..lineTo(h / 2, 0)
      ..lineTo(size.width - h / 2, 0)
      ..lineTo(size.width, h / 2)
      ..lineTo(size.width - h / 2, h)
      ..lineTo(h / 2, h)
      ..close();
    canvas
      ..drawPath(outline, Paint()..color = _track)
      ..save()
      ..clipPath(outline);
    final width = size.width * _segment;
    final left =
        (size.width - width) * Curves.easeInOut.transform(progress.value);
    canvas
      ..drawRect(Rect.fromLTWH(left, 0, width, h), Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_SyncBarPainter old) => old.color != color;
}
