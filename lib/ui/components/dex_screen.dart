import 'package:flutter/material.dart';

import '../themes/regi_theme.dart';

/// Pantalla de la Pokédex: fondo del tema, borde con color de carcasa,
/// bisel interior y la esquina inferior derecha redondeada.
class DexScreen extends StatelessWidget {
  const DexScreen({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Radio de la esquina inferior redondeada.
  static const cornerRadius = 28.0;

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    const corner = BorderRadius.only(
      bottomRight: Radius.circular(cornerRadius),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: regi.screen,
        borderRadius: corner,
        border: Border.all(color: regi.frame, width: 2),
      ),
      child: DecoratedBox(
        // Bisel: un segundo trazo tenue dentro del borde.
        decoration: BoxDecoration(
          borderRadius: corner,
          border: Border.all(
            color: regi.onScreen.withValues(alpha: 0.12),
            width: 3,
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
