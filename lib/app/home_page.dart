import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/settings/presentation/settings_dialog.dart';
import '../ui/components/hub_buttons.dart';
import '../ui/themes/regi_theme.dart';
import '../ui/tokens/contrast.dart';
import '../ui/tokens/regi_colors.dart';
import 'routes.dart';

/// Pantalla de Inicio: acceso a Catálogo, Favoritos, Equipos, Trivia y Ajustes
/// (este último abre una ventana emergente, no una pantalla).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  /// Ancho útil desde el que los tres botones caben en una fila.
  static const _rowBreakpoint = 360.0;

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _rowBreakpoint;
        final octagon = (constraints.maxWidth * .56).clamp(150.0, 260.0);

        final favorites = HexButton(
          label: 'Favoritos',
          color: RegiHubColors.favorites,
          onPressed: () => context.go(AppRoutes.favorites),
        );
        final trivia = HexButton(
          label: 'Trivia',
          color: RegiHubColors.trivia,
          onPressed: () => context.go(AppRoutes.trivia),
        );
        final teams = HexButton(
          label: 'Equipos',
          color: RegiHubColors.teams,
          onPressed: () => context.go(AppRoutes.teamBuilder),
        );

        // Con poco alto o texto grande el contenido se desplaza en lugar de
        // desbordar; el panel claro de abajo ocupa el sobrante cuando hay sitio.
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ColoredBox(
                    color: regi.frame,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: HexIconButton(
                          icon: Icons.tune,
                          label: 'Ajustes',
                          labelColor: readableOn(regi.frame),
                          onPressed: () => showSettingsDialog(context),
                        ),
                      ),
                    ),
                  ),
                  _HubStage(
                    size: octagon,
                    // TODO(RD-14): los ojos LED de la Regi van en `child`.
                    child: OctagonHubButton(
                      label: 'Catálogo',
                      size: octagon,
                      onPressed: () => context.go(AppRoutes.catalog),
                    ),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: regi.screen,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 24, 12, 20),
                          child: wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 10,
                                  children: [
                                    Expanded(child: favorites),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 14),
                                        child: trivia,
                                      ),
                                    ),
                                    Expanded(child: teams),
                                  ],
                                )
                              : ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 240,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    spacing: 10,
                                    children: [
                                      for (final button in [
                                        favorites,
                                        trivia,
                                        teams,
                                      ])
                                        SizedBox(
                                          width: double.infinity,
                                          child: button,
                                        ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Franja central de Inicio: el octógono sobre tres franjas en ángulo (marrón
/// claro, marrón oscuro y negro) y el panel claro de abajo.
class _HubStage extends StatelessWidget {
  const _HubStage({required this.size, required this.child});

  /// Lado del octógono; las franjas se miden contra él.
  final double size;
  final Widget child;

  static const _padding = 14.0;

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    return CustomPaint(
      painter: _HubBackdropPainter(
        top: regi.frame,
        screen: regi.screen,
        ink: regi.shell,
        octagon: size,
      ),
      child: SizedBox(
        height: size + _padding * 2,
        child: Center(child: child),
      ),
    );
  }
}

/// Tres bordes con forma de «∧» muy abierta, centrados en el octógono:
/// marrón claro → marrón oscuro, marrón oscuro → negro (línea blanca) y
/// negro → panel claro (línea blanca).
class _HubBackdropPainter extends CustomPainter {
  const _HubBackdropPainter({
    required this.top,
    required this.screen,
    required this.ink,
    required this.octagon,
  });

  final Color top;
  final Color screen;
  final Color ink;
  final double octagon;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final w = size.width;
    final c = size.height / 2;
    final rise = octagon * .153;

    // Cada borde: altura en el centro; en los extremos queda `rise` más abajo.
    Path edge(double centerY) => Path()
      ..moveTo(0, centerY + rise)
      ..lineTo(w / 2, centerY)
      ..lineTo(w, centerY + rise);

    Path band(double upper, double lower) => Path()
      ..moveTo(0, upper + rise)
      ..lineTo(w / 2, upper)
      ..lineTo(w, upper + rise)
      ..lineTo(w, lower + rise)
      ..lineTo(w / 2, lower)
      ..lineTo(0, lower + rise)
      ..close();

    final b1 = c - octagon * .37;
    final b2 = c - octagon * .02;
    final b3 = c + octagon * .33;
    final bottom = size.height + rise;

    canvas.drawRect(Offset.zero & size, Paint()..color = top);
    canvas.drawPath(
      band(b1, b2),
      Paint()..color = Color.lerp(top, Colors.black, .3)!,
    );
    canvas.drawPath(band(b2, b3), Paint()..color = ink);
    canvas.drawPath(band(b3, bottom), Paint()..color = screen);

    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.miter;
    canvas.drawPath(edge(b2), line);
    canvas.drawPath(edge(b3), line);
  }

  @override
  bool shouldRepaint(_HubBackdropPainter old) =>
      old.top != top ||
      old.screen != screen ||
      old.ink != ink ||
      old.octagon != octagon;
}
