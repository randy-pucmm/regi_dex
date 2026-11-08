import 'package:flutter/material.dart';

import '../themes/regi_theme.dart';
import '../tokens/led_state.dart';
import 'led_eyes.dart';
import 'pokedex_shell.dart';
import 'status_popover.dart';

/// El lente con los ojos del Regi: dice el estado de la conexión y, al tocarlo,
/// despliega el detalle con «Sincronizar ahora». Es un botón de al menos 48 dp.
class StatusLed extends StatelessWidget {
  const StatusLed({
    super.key,
    required this.state,
    required this.semanticsLabel,
    required this.details,
  });

  final LedState state;
  final String semanticsLabel;

  final StatusDetails details;

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    return Builder(
      builder: (context) {
        void open() {
          final box = context.findRenderObject()! as RenderBox;
          showStatusPopover(
            context: context,
            anchor: box.localToGlobal(Offset.zero) & box.size,
            state: state,
            details: details,
          );
        }

        return Semantics(
          button: true,
          label: semanticsLabel,
          hint: 'Ver detalle de la conexión',
          excludeSemantics: true,
          onTap: open,
          child: InkResponse(
            onTap: open,
            customBorder: const CircleBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: ShellLens(
                ringColor: regi.ledColor(state),
                child: LedEyes(state: state, size: 52),
              ),
            ),
          ),
        );
      },
    );
  }
}
