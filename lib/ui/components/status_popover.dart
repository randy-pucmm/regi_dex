import 'package:flutter/material.dart';

import '../themes/regi_theme.dart';
import '../tokens/led_state.dart';
import '../tokens/regi_colors.dart';
import 'hub_buttons.dart';
import 'led_eyes.dart';
import 'reduced_motion.dart';
import 'shell_status_band.dart';

@immutable
class StatusRow {
  const StatusRow(this.label, this.value);

  final String label;
  final String value;
}

@immutable
class StatusDetails {
  const StatusDetails({
    required this.title,
    required this.subtitle,
    required this.message,
    this.rows = const [],
    this.syncing = false,
    this.onSyncNow,
  });

  /// Estado, en la banda del desplegable.
  final String title;

  /// Origen y vigencia de los datos, en la banda.
  final String subtitle;

  final String message;
  final List<StatusRow> rows;
  final bool syncing;

  /// Null deshabilita «Sincronizar ahora» (sin red o ya sincronizando).
  final VoidCallback? onSyncNow;
}

/// Despliega el estado como un menú justo debajo de [anchor] (el LED). Se
/// recoge tocando fuera, con «atrás» o con «Sincronizar ahora».
Future<void> showStatusPopover({
  required BuildContext context,
  required Rect anchor,
  required LedState state,
  required StatusDetails details,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.transparent,
    transitionDuration: reducedMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 220),
    // La animación la hace el propio panel, no la ruta.
    transitionBuilder: (context, animation, _, child) => child,
    pageBuilder: (context, animation, _) => _PopoverLayout(
      anchor: anchor,
      state: state,
      details: details,
      animation: animation,
    ),
  );
}

class _PopoverLayout extends StatelessWidget {
  const _PopoverLayout({
    required this.anchor,
    required this.state,
    required this.details,
    required this.animation,
  });

  final Rect anchor;
  final LedState state;
  final StatusDetails details;
  final Animation<double> animation;

  static const _sideInset = 20.0;
  static const _caretWidth = 20.0;
  static const _caretHeight = 10.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final top = anchor.bottom + 4;
    final maxHeight = media.size.height - top - media.padding.bottom - 12;
    final regi = RegiTheme.of(context);
    final tone = regi.ledColor(state);
    final caretLeft = (anchor.center.dx - _sideInset - _caretWidth / 2).clamp(
      12.0,
      double.infinity,
    );
    final reveal = animation.drive(CurveTween(curve: Curves.easeOutCubic));

    return Stack(
      children: [
        Positioned(
          top: top,
          left: _sideInset,
          right: _sideInset,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight < 0 ? 0 : maxHeight,
            ),
            // La flecha se pinta por encima del panel y su sombra.
            child: CustomPaint(
              foregroundPainter: _CaretPainter(tone, left: caretLeft),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: _caretHeight),
                  Flexible(
                    child: SizeTransition(
                      sizeFactor: reveal,
                      alignment: Alignment.topCenter,
                      child: FadeTransition(
                        opacity: reveal,
                        child: _Panel(
                          state: state,
                          tone: tone,
                          details: details,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CaretPainter extends CustomPainter {
  _CaretPainter(this.color, {required this.left});

  final Color color;
  final double left;

  @override
  void paint(Canvas canvas, Size size) {
    const width = _PopoverLayout._caretWidth;
    const height = _PopoverLayout._caretHeight;
    canvas.drawPath(
      Path()
        ..moveTo(left, height + 1)
        ..lineTo(left + width / 2, 0)
        ..lineTo(left + width, height + 1)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_CaretPainter old) =>
      old.color != color || old.left != left;
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.state,
    required this.tone,
    required this.details,
  });

  final LedState state;
  final Color tone;
  final StatusDetails details;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shape = BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: tone, width: 2),
    );
    return Material(
      color: RegiInk.panel,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: details.title,
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: RegiInk.onShell),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShellStatusBand(
                  color: tone,
                  title: details.title,
                  subtitle: details.subtitle,
                  progress: details.syncing,
                  leading: LedEyes(state: state, size: 46),
                  trailing: LedEyes(state: state, size: 46),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 14, 6, 0),
                  child: Text(
                    details.message,
                    style: text.bodyMedium?.copyWith(color: RegiInk.onShell),
                  ),
                ),
                if (details.rows.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 16, 6, 0),
                    child: _Rows(rows: details.rows),
                  ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: HexButton(
                        label: 'Sincronizar ahora',
                        color: tone,
                        onPressed: details.onSyncNow == null
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                details.onSyncNow!();
                              },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.rows});

  final List<StatusRow> rows;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      children: [
        for (final row in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 18, bottom: 7),
                child: Text(
                  row.label.toUpperCase(),
                  style: text.labelLarge?.copyWith(
                    color: RegiInk.onShellMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Semantics(
                  label: '${row.label}: ${row.value}',
                  excludeSemantics: true,
                  child: Text(
                    row.value,
                    style: text.bodyMedium?.copyWith(color: RegiInk.onShell),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
