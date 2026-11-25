import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/features/settings/presentation/appearance_controller.dart';
import 'package:regi_dex/ui/themes/regi_themes.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

import '../../core/database/database_test_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
    addTearDown(db.close);
  });

  ProviderContainer container() {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('empieza con Regirock en modo claro', () async {
    final appearance = container().read(appearanceProvider);
    expect(appearance.variant, RegiThemes.defaultVariant);
    expect(appearance.variant, RegiVariant.regirock);
    expect(appearance.mode, ThemeMode.light);
    await pumpEventQueue();
  });

  test('cambiar el tema no toca el modo, y al revés', () async {
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
    await pumpEventQueue();
  });

  test('el tema y el modo elegidos sobreviven a un reinicio', () async {
    final first = container();
    first.read(appearanceProvider.notifier)
      ..selectVariant(RegiVariant.regidrago)
      ..selectMode(ThemeMode.dark);
    await pumpEventQueue();

    final restarted = container();
    restarted.read(appearanceProvider);
    await pumpEventQueue();

    expect(
      restarted.read(appearanceProvider),
      const Appearance(variant: RegiVariant.regidrago, mode: ThemeMode.dark),
    );
  });

  test('un valor guardado inválido cae al tema por defecto', () async {
    await db.preferenceDao.setValue(themePreferenceKey, 'mewtwo');
    final c = container();
    c.read(appearanceProvider);
    await pumpEventQueue();

    expect(c.read(appearanceProvider), const Appearance());
  });
}
