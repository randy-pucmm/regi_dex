import 'package:flutter/material.dart';

import '../tokens/contrast.dart';
import '../tokens/regi_colors.dart';

/// Etiqueta de tipo Pokémon. [typeKey] es la clave de PokéAPI (`rock`) y
/// [label] el nombre traducido; con [onTap] es un botón de al menos 48 dp. Con
/// [selected] es una opción de un filtro: la elegida lleva «✓» y un aro blanco,
/// no solo color.
class TypeChip extends StatelessWidget {
  const TypeChip({
    super.key,
    required this.typeKey,
    required this.label,
    this.onTap,
    this.selected,
  });

  final String typeKey;
  final String label;
  final VoidCallback? onTap;

  /// null: etiqueta o botón simple. true/false: opción elegida o no.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final color = RegiTypeColors.of(typeKey);
    final foreground = readableOn(color);
    final chosen = selected == true;
    final chip = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        // El aro de la elegida; la que no, deja el hueco para no mover nada.
        border: selected == null
            ? null
            : Border.all(
                color: chosen ? RegiInk.onShell : Colors.transparent,
                width: 2,
              ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: selected == null ? 10 : 8,
          vertical: selected == null ? 3 : 1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chosen) ...[
              Icon(Icons.check, size: 14, color: foreground),
              const SizedBox(width: 3),
            ],
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return Semantics(
        label: 'Tipo $label',
        excludeSemantics: true,
        child: chip,
      );
    }
    return Semantics(
      label: 'Tipo $label',
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(widthFactor: 1, heightFactor: 1, child: chip),
        ),
      ),
    );
  }
}
