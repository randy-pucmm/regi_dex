import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/features/settings/presentation/appearance_controller.dart';
import 'package:regi_dex/ui/themes/regi_themes.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

void main() {
  ProviderContainer container() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('empieza con Regirock en modo claro', () {
    final appearance = container().read(appearanceProvider);
    expect(appearance.variant, RegiThemes.defaultVariant);
    expect(appearance.variant, RegiVariant.regirock);
    expect(appearance.mode, ThemeMode.light);
  });

  test('cambiar el tema no toca el modo, y al revés', () {
    final c = container();
    final controller = c.read(appearanceProvider.notifier);

    controller.selectVariant(RegiVariant.regice);
    expect(
      c.read(appearanceProvider),
      const Appearance(variant: RegiVariant.regice),
    );

    controller.selectMode(ThemeMode.dark);
    expect(
      c.read(appearanceProvider),
      const Appearance(variant: RegiVariant.regice, mode: ThemeMode.dark),
    );
  });

  test('avisa a quien escucha en cada cambio', () {
    final c = container();
    final seen = <Appearance>[];
    c.listen(appearanceProvider, (_, next) => seen.add(next));

    c.read(appearanceProvider.notifier)
      ..selectVariant(RegiVariant.regidrago)
      ..selectMode(ThemeMode.dark);

    expect(seen, hasLength(2));
    expect(seen.last.variant, RegiVariant.regidrago);
    expect(seen.last.mode, ThemeMode.dark);
  });
}
