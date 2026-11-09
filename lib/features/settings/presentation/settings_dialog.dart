import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/components/hex_choice.dart';
import '../../../ui/components/regi_dialog.dart';
import '../../../ui/themes/regi_theme.dart';
import '../../../ui/tokens/regi_colors.dart';
import '../../../ui/tokens/regi_palette.dart';
import 'appearance_controller.dart';

/// Ajustes en una ventana bajo la cabecera, para ver el cambio de tema en vivo.
class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  /// Alto de la cabecera de la carcasa, sin contar la barra de estado.
  static const _headerHeight = 136.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);
    final top = MediaQuery.paddingOf(context).top + _headerHeight;

    return RegiDialog(
      title: 'Ajustes',
      alignment: Alignment.topCenter,
      insetPadding: EdgeInsets.fromLTRB(20, top, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel('Tema Regi'),
          const SizedBox(height: 10),
          GridView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 52,
            ),
            children: [
              for (final variant in RegiVariant.values)
                HexChoice(
                  label: variant.displayName,
                  selected: appearance.variant == variant,
                  // La muestra es el borde del tema en el modo actual.
                  leading: _Swatch(
                    RegiTheme.forVariant(
                      variant,
                      Theme.of(context).brightness,
                    ).frame,
                  ),
                  onPressed: () => controller.selectVariant(variant),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Modo'),
          const SizedBox(height: 10),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: HexChoice(
                  label: 'Claro',
                  filled: true,
                  selected: appearance.mode == ThemeMode.light,
                  onPressed: () => controller.selectMode(ThemeMode.light),
                ),
              ),
              Expanded(
                child: HexChoice(
                  label: 'Oscuro',
                  filled: true,
                  selected: appearance.mode == ThemeMode.dark,
                  onPressed: () => controller.selectMode(ThemeMode.dark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 128,
              child: HexChoice(
                label: 'Listo',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: RegiInk.onShellMuted, letterSpacing: 2),
      ),
    );
  }
}

/// Muestra de color con aro blanco para verse sobre fondo oscuro.
class _Swatch extends StatelessWidget {
  const _Swatch(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: RegiInk.onShell, width: 1.5),
      ),
      child: const SizedBox.square(dimension: 18),
    );
  }
}

/// Sin oscurecer el fondo, para ver el cambio mientras se elige.
Future<void> showSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    barrierLabel: 'Cerrar',
    builder: (context) => const SettingsDialog(),
  );
}
