import 'package:flutter/material.dart';

import '../tokens/contrast.dart';
import '../tokens/regi_colors.dart';

/// Etiqueta de tipo Pokémon. [typeKey] es la clave de PokéAPI (`rock`) y
/// [label] el nombre traducido; con [onTap] es un botón de al menos 48 dp.
class TypeChip extends StatelessWidget {
  const TypeChip({
    super.key,
    required this.typeKey,
    required this.label,
    this.onTap,
  });

  final String typeKey;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = RegiTypeColors.of(typeKey);
    final chip = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: readableOn(color), fontWeight: FontWeight.w700),
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
