import 'package:flutter/material.dart';

import '../tokens/contrast.dart';
import '../tokens/regi_colors.dart';

/// Opción de un filtro para las ventanas oscuras: texto en una pastilla de al
/// menos 48 dp de alto. La elegida se rellena de blanco y lleva «✓», no solo
/// color. Sirve para grupos de varias opciones a la vez.
class RegiFilterChip extends StatelessWidget {
  const RegiFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? readableOn(RegiInk.onShell) : RegiInk.onShell;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(
        color: selected ? RegiInk.onShell : const Color(0xFF7C858B),
        width: selected ? 2 : 1.5,
      ),
    );
    return Semantics(
      button: true,
      label: label,
      selected: selected,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? RegiInk.onShell : Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(Icons.check, size: 18, color: foreground),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
