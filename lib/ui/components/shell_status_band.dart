import 'package:flutter/material.dart';

import '../themes/regi_theme.dart';
import 'hexagon_border.dart';

/// Banda hexagonal de estado bajo la cabecera de la Pokédex.
///
/// Muestra dos líneas (estado y origen·vigencia) con un [leading] y un
/// [trailing] a los lados (los ojos LED). El color del borde y del título
/// es el del estado, pero el estado también se dice con texto.
/// Con [onTap] es un botón; la banda ya mide más de 48 dp de alto.
class ShellStatusBand extends StatelessWidget {
  const ShellStatusBand({
    super.key,
    required this.color,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final Color color;
  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: regi.onShell),
                ),
              ],
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
