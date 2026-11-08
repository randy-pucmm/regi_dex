import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../themes/regi_theme.dart';
import '../tokens/regi_colors.dart';
import 'hexagon_border.dart';

/// Botón hexagonal de destino de Inicio (Favoritos, Trivia, Equipos).
///
/// Fondo oscuro con borde y texto del [color] del destino; el nombre también
/// está escrito, así que el color no es lo único que lo identifica.
class HexButton extends StatelessWidget {
  const HexButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  static const _pointDepth = 16.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shape = HexagonBorder(
      pointAxis: Axis.horizontal,
      depth: _pointDepth,
      side: BorderSide(color: color, width: 2),
    );
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: RegiInk.shell,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _pointDepth + 6,
                vertical: 8,
              ),
              // heightFactor: el botón mide lo que su texto, no todo el alto
              // que le ofrezca el contenedor.
              child: Center(
                heightFactor: 1,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label.toUpperCase(),
                    style: text.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
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

/// Hexágono con icono y nombre debajo (Ajustes). El [labelColor] debe
/// contrastar con el fondo sobre el que se coloque.
class HexIconButton extends StatelessWidget {
  const HexIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.labelColor,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color labelColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shape = HexagonBorder(
      pointAxis: Axis.horizontal,
      depth: 15,
      side: const BorderSide(color: RegiInk.onShell, width: 2),
    );
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      // Material propio y transparente: el `Ink` pinta sobre el Material más
      // cercano, y el de la carcasa queda tapado por el fondo de Inicio.
      child: Material(
        type: MaterialType.transparency,
        child: InkResponse(
          onTap: onPressed,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Ink(
                  decoration: ShapeDecoration(
                    color: RegiInk.shell,
                    shape: shape,
                  ),
                  width: 68,
                  height: 58,
                  child: Icon(icon, color: RegiInk.onShell),
                ),
                const SizedBox(height: 4),
                Text(
                  label.toUpperCase(),
                  style: text.labelSmall?.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón octogonal regular de Inicio (Catálogo): cuadrado de lado [size], marco
/// blanco con un filete del color del tema, [child] en la parte alta (los ojos
/// LED) y el nombre en una placa hexagonal.
class OctagonHubButton extends StatelessWidget {
  const OctagonHubButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = 220,
    this.child,
  });

  final String label;
  final VoidCallback onPressed;

  /// Lado del cuadrado que contiene al octógono.
  final double size;
  final Widget? child;

  /// Lo que entra cada esquina para que los ocho lados sean iguales:
  /// 1 / (2 + √2) del lado.
  static const chamferRatio = 1 / (2 + math.sqrt2);

  static const _outerWidth = 3.0;
  static const _innerWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    final text = Theme.of(context).textTheme;
    final chamfer = size * chamferRatio;
    final outer = BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(chamfer),
      side: const BorderSide(color: Colors.white, width: _outerWidth),
    );
    // Al entrar el marco, cada bisel se acorta 3·(2 − √2) para seguir paralelo.
    final inner = BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(
        chamfer - _outerWidth * (2 - math.sqrt2),
      ),
      side: BorderSide(color: regi.frame, width: _innerWidth),
    );
    final plateHeight = size * .245;
    final plate = HexagonBorder(
      pointAxis: Axis.horizontal,
      depth: plateHeight * .33,
      side: BorderSide(color: regi.frame, width: 2),
    );
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: RegiInk.panel,
          shape: outer,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: outer,
            child: Padding(
              padding: const EdgeInsets.all(_outerWidth),
              child: DecoratedBox(
                decoration: ShapeDecoration(shape: inner),
                child: Stack(
                  children: [
                    if (child != null)
                      Align(alignment: const Alignment(0, -.5), child: child),
                    Align(
                      alignment: const Alignment(0, .43),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: regi.shell,
                            shape: plate,
                          ),
                          child: SizedBox(
                            height: plateHeight,
                            width: double.infinity,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: plateHeight * .33 + 6,
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    label.toUpperCase(),
                                    style: text.titleLarge?.copyWith(
                                      color: regi.onShell,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
