import 'package:flutter/material.dart';

import '../themes/regi_theme.dart';
import '../tokens/regi_colors.dart';

/// Una estadística base: etiqueta, valor y barra proporcional.
///
/// Está pensada para fondos oscuros (la carcasa o las celdas del detalle):
/// el valor usa `onShell` y la etiqueta, el color de la estadística.
class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.stat,
    required this.value,
    this.max = 255,
  });

  /// Estadística que representa; define etiqueta y color.
  final RegiStat stat;
  final int value;

  /// Valor que llena la barra por completo (255 es el tope de PokéAPI).
  final int max;

  /// Fracción de la barra que se pinta, entre 0 y 1.
  double get fraction => max <= 0 ? 0 : (value / max).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '${stat.label}: $value de $max',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stat.label,
            style: text.labelSmall?.copyWith(
              color: stat.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '$value',
            style: text.headlineMedium?.copyWith(color: regi.onShell),
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xFF2A3033)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fraction,
                    child: ColoredBox(color: stat.color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
