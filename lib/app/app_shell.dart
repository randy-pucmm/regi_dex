import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/pokedex_shell.dart';
import '../ui/components/shell_status_band.dart';
import '../ui/themes/regi_theme.dart';
import 'routes.dart';

/// Carcasa común de las pantallas: la Pokédex del kit `lib/ui` con el botón
/// «Inicio» fuera de Inicio.
///
/// TODO(RD-14): el estado de la cabecera es fijo y solo visual. Cuando exista
/// el estado de conectividad, el lente, los indicadores y la banda se
/// construirán con él (StatusLed) en lugar de estas constantes.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    final atHome = GoRouterState.of(context).uri.path == AppRoutes.home;
    return PokedexShell(
      updatedLabel: 'ACT. --:--',
      indicators: [
        ShellIndicator(
          label: 'RED',
          color: regi.ledOnline,
          semanticsLabel: 'Red: conectada',
        ),
        ShellIndicator(
          label: 'API',
          color: regi.ledOnline,
          semanticsLabel: 'API: disponible',
        ),
        ShellIndicator(
          label: 'DATOS',
          color: regi.ledOnline,
          semanticsLabel: 'Datos: remotos',
        ),
      ],
      lens: ShellLens(ringColor: regi.ledOnline, child: const SizedBox()),
      statusBand: ShellStatusBand(
        color: regi.ledOnline,
        title: 'En línea',
        subtitle: 'Datos remotos · actualizado --:--',
      ),
      bottomBar: atHome
          ? null
          : ShellHomeButton(onPressed: () => context.go(AppRoutes.home)),
      child: child,
    );
  }
}
