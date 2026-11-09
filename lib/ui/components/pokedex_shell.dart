import 'package:flutter/material.dart';

import '../themes/regi_theme.dart';
import '../tokens/regi_colors.dart';
import 'hexagon_border.dart';
import 'indicator_glyph.dart';

/// Marca de color con etiqueta de la cabecera (RED, API, DATOS).
@immutable
class ShellIndicator {
  const ShellIndicator({
    required this.label,
    required this.color,
    required this.semanticsLabel,
    this.glyph = IndicatorGlyph.solid,
  });

  final String label;
  final Color color;

  /// La forma evita que el estado dependa solo del color.
  final IndicatorGlyph glyph;
  final String semanticsLabel;
}

/// Carcasa de la Pokédex: marco biselado, cabecera con lente y título, contenido
/// y barra inferior.
///
/// La cabecera no escala el texto por encima de 1.3× para no romper la carcasa.
class PokedexShell extends StatelessWidget {
  const PokedexShell({
    super.key,
    required this.child,
    required this.lens,
    this.statusBand,
    this.updatedLabel,
    this.indicators = const [],
    this.bottomBar,
  });

  final Widget child;

  /// El LED de conectividad.
  final Widget lens;

  /// Banda fija bajo el título; opcional.
  final Widget? statusBand;

  /// P. ej. «ACT. 10:42».
  final String? updatedLabel;

  final List<ShellIndicator> indicators;
  final Widget? bottomBar;

  static const _frameWidth = 5.0;

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    final outer = BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: regi.frame, width: _frameWidth),
    );
    final inner = BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(17),
      side: const BorderSide(color: Colors.white, width: 1.5),
    );

    // Material propio: los InkWell de la cabecera y la barra necesitan uno.
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: outer),
            child: DecoratedBox(
              decoration: ShapeDecoration(color: regi.shell, shape: outer),
              child: Padding(
                padding: const EdgeInsets.all(_frameWidth),
                child: DecoratedBox(
                  decoration: ShapeDecoration(shape: inner),
                  child: ClipPath(
                    clipper: ShapeBorderClipper(shape: inner),
                    child: Column(
                      children: [
                        MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.3,
                          child: _Header(
                            lens: lens,
                            statusBand: statusBand,
                            updatedLabel: updatedLabel,
                            indicators: indicators,
                          ),
                        ),
                        Expanded(
                          child: ColoredBox(color: regi.screen, child: child),
                        ),
                        if (bottomBar != null)
                          MediaQuery.withClampedTextScaling(
                            maxScaleFactor: 1.3,
                            child: _BottomBar(child: bottomBar!),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.lens,
    required this.statusBand,
    required this.updatedLabel,
    required this.indicators,
  });

  final Widget lens;
  final Widget? statusBand;
  final String? updatedLabel;
  final List<ShellIndicator> indicators;

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: regi.shell,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Row(
              children: [
                if (updatedLabel != null)
                  Text(
                    updatedLabel!,
                    style: text.labelSmall?.copyWith(color: regi.onShellMuted),
                  ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final indicator in indicators)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: _IndicatorDot(indicator: indicator),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: regi.onShell.withValues(alpha: .12),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 68, height: 68, child: lens),
                const SizedBox(width: 12),
                const Expanded(child: _Wordmark()),
              ],
            ),
          ),
          if (statusBand case final band?)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: band,
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _IndicatorDot extends StatelessWidget {
  const _IndicatorDot({required this.indicator});

  final ShellIndicator indicator;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: indicator.semanticsLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IndicatorMark(glyph: indicator.glyph, color: indicator.color),
          const SizedBox(width: 5),
          Text(
            indicator.label,
            style: text.labelSmall?.copyWith(
              color: indicator.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// «R E G I D E X» con cada letra en un hexágono, y el subtítulo debajo.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  static const _letters = ['R', 'E', 'G', 'I', 'D', 'E', 'X'];

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      header: true,
      label: 'RegiDex, Pokédex Nacional, 1025',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final letter in _letters)
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: HexagonBorder(
                          side: BorderSide(color: regi.onShell, width: 1.5),
                        ),
                      ),
                      child: SizedBox(
                        width: 28,
                        height: 32,
                        child: Center(
                          child: Text(
                            letter,
                            style: text.titleMedium?.copyWith(
                              color: regi.onShell,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'POKÉDEX NACIONAL · 1 025',
            style: text.labelSmall?.copyWith(
              color: regi.onShellMuted,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: regi.shell,
        border: Border(top: BorderSide(color: regi.frame, width: 2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(child: child),
      ),
    );
  }
}

/// Lente metálico de la cabecera.
class ShellLens extends StatelessWidget {
  const ShellLens({super.key, required this.child, required this.ringColor});

  final Widget child;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE3E6E8), Color(0xFF6E767B), Color(0xFFC9CED1)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: RegiLedColors.off,
            border: Border.all(color: ringColor, width: 3),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Botón hexagonal «Inicio» de la barra inferior.
class ShellHomeButton extends StatelessWidget {
  const ShellHomeButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    final text = Theme.of(context).textTheme;
    final shape = HexagonBorder(
      pointAxis: Axis.horizontal,
      depth: 14,
      side: BorderSide(color: regi.ledOnline, width: 2),
    );
    return Semantics(
      button: true,
      label: 'Inicio',
      excludeSemantics: true,
      onTap: onPressed,
      child: InkResponse(
        onTap: onPressed,
        customBorder: shape,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: ShapeDecoration(shape: shape),
                child: SizedBox(
                  width: 56,
                  height: 40,
                  child: Icon(Icons.home_outlined, color: regi.ledOnline),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Inicio',
                style: text.labelSmall?.copyWith(
                  color: regi.onShell,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
