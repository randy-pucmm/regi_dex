import 'package:flutter/material.dart';

import '../tokens/contrast.dart';
import '../tokens/regi_colors.dart';
import 'hexagon_border.dart';

/// Botón hexagonal para las ventanas oscuras de la Pokédex.
///
/// Con [selected] es una opción de un grupo: la elegida lleva borde blanco y
/// «✓» (con [filled], además fondo blanco), así que no depende solo del color.
/// Sin [selected] es una acción (p. ej. «Listo»), con borde blanco.
class HexChoice extends StatelessWidget {
  const HexChoice({
    super.key,
    required this.label,
    required this.onPressed,
    this.selected,
    this.filled = false,
    this.leading,
  });

  final String label;
  final VoidCallback onPressed;

  /// null: acción. true/false: opción elegida o no.
  final bool? selected;

  /// La opción elegida se rellena de blanco.
  final bool filled;

  /// Adorno antes del texto (p. ej. la muestra de color de un tema).
  final Widget? leading;

  static const _pointDepth = 16.0;

  /// Borde de una opción sin elegir: gris que se distingue del fondo oscuro.
  static const unselectedBorder = Color(0xFF7C858B);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isChosen = selected ?? true;
    final fill = filled && selected == true ? RegiInk.onShell : null;
    final foreground = fill == null ? RegiInk.onShell : readableOn(fill);
    final shape = HexagonBorder(
      pointAxis: Axis.horizontal,
      depth: _pointDepth,
      side: BorderSide(
        color: isChosen ? RegiInk.onShell : unselectedBorder,
        width: isChosen ? 2 : 1.5,
      ),
    );
    return Semantics(
      button: true,
      label: label,
      selected: selected,
      inMutuallyExclusiveGroup: selected == null ? null : true,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: fill ?? Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _pointDepth + 4,
                vertical: 6,
              ),
              child: Center(
                heightFactor: 1,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 8),
                      ],
                      // Icono y no el carácter «✓»: Chakra Petch no lo trae.
                      if (selected == true) ...[
                        Icon(Icons.check, size: 18, color: foreground),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        label.toUpperCase(),
                        style: text.titleSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                        ),
                      ),
                    ],
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
