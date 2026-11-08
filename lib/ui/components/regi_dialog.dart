import 'package:flutter/material.dart';

import '../tokens/regi_colors.dart';

/// Ventana emergente oscura de la Pokédex: esquinas biseladas, filete claro y
/// el título arriba. No trae botón de cierre: el contenido ofrece el suyo
/// («Listo») y `showDialog` ya cierra al tocar fuera o con «atrás».
///
/// Es para contenido corto; si crece, el cuerpo se desplaza.
class RegiDialog extends StatelessWidget {
  const RegiDialog({
    super.key,
    required this.title,
    required this.child,
    this.alignment = Alignment.center,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 24,
    ),
  });

  final String title;
  final Widget child;

  /// Dónde se ancla la ventana (arriba para dejar a la vista la cabecera).
  final AlignmentGeometry alignment;
  final EdgeInsets insetPadding;

  static const _maxWidth = 420.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shape = BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: RegiInk.onShellMuted, width: 1.5),
    );
    return Dialog(
      backgroundColor: RegiInk.panel,
      shadowColor: Colors.black,
      elevation: 12,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      alignment: alignment,
      insetPadding: insetPadding,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: title,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: RegiInk.onShell),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title.toUpperCase(),
                      style: text.headlineSmall?.copyWith(
                        color: RegiInk.onShell,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
