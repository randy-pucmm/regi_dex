import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/app.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/features/settings/presentation/settings_dialog.dart';
import 'package:regi_dex/ui/components/hex_choice.dart';
import 'package:regi_dex/ui/components/hub_buttons.dart';
import 'package:regi_dex/ui/components/pokedex_shell.dart';
import 'package:regi_dex/ui/themes/regi_theme.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

import '../core/connectivity/connectivity_fakes.dart';
import '../core/database/database_test_helpers.dart';
import '../features/pokemon/fake_pokemon_repository.dart';

/// Destinos de Inicio que abren una pantalla (Ajustes abre una ventana).
const _screens = ['Catálogo', 'Favoritos', 'Equipos', 'Trivia'];

/// Abre la app sin red real ni disco: BD en memoria y repositorio falso, para
/// que la sincronización automática no salga a PokéAPI.
Future<void> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final db = createTestDatabase();
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        networkSourceProvider.overrideWithValue(FakeNetworkSource()),
        healthCheckerProvider.overrideWithValue(FakeHealthChecker()),
        appDatabaseProvider.overrideWithValue(db),
        pokemonRepositoryProvider.overrideWithValue(FakePokemonRepository()),
      ],
      child: const RegiDexApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Texto del botón de Inicio de un destino (los botones van en mayúsculas).
Finder _hubButton(String label) => find.text(label.toUpperCase());

/// El «✓» de la opción de Ajustes con ese texto.
Finder _checkIn(String label) => find.descendant(
  of: find.widgetWithText(HexChoice, label),
  matching: find.byIcon(Icons.check),
);

void main() {
  testWidgets('abre en Inicio con los cinco destinos', (tester) async {
    await _pumpApp(tester);

    for (final label in [..._screens, 'Ajustes']) {
      expect(_hubButton(label), findsOneWidget);
    }
    expect(find.text('Inicio'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('los botones inferiores miden lo que su texto, no se estiran', (
    tester,
  ) async {
    await _pumpApp(tester);

    for (final button in tester.widgetList(find.byType(HexButton)).indexed) {
      final size = tester.getSize(find.byType(HexButton).at(button.$1));
      expect(size.height, inInclusiveRange(48, 80));
    }
  });

  testWidgets('cada pantalla se abre y «Inicio» regresa al hub', (
    tester,
  ) async {
    await _pumpApp(tester);

    for (final label in _screens) {
      await tester.tap(_hubButton(label));
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
      expect(_hubButton(label), findsNothing);

      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      expect(_hubButton(label), findsOneWidget);
    }
  });

  testWidgets('Ajustes abre una ventana sobre Inicio y «Listo» la cierra', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(_hubButton('Ajustes'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsDialog), findsOneWidget);
    // Sigue en Inicio: no hay botón «Inicio» y el hub está debajo.
    expect(find.text('Inicio'), findsNothing);
    expect(_hubButton('Catálogo'), findsOneWidget);

    await tester.tap(find.text('LISTO'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsDialog), findsNothing);
    expect(_hubButton('Catálogo'), findsOneWidget);
  });

  testWidgets('la ventana de Ajustes también se cierra tocando fuera', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(_hubButton('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsDialog), findsNothing);
  });

  testWidgets('Ajustes lista los seis temas y los dos modos', (tester) async {
    await _pumpApp(tester);
    await tester.tap(_hubButton('Ajustes'));
    await tester.pumpAndSettle();

    for (final variant in RegiVariant.values) {
      final label = variant.displayName.toUpperCase();
      expect(find.text(label), findsOneWidget);
    }
    // Regirock y Claro son lo elegido al inicio: llevan «✓».
    expect(_checkIn('REGIROCK'), findsOneWidget);
    expect(_checkIn('CLARO'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(2));
    expect(find.text('OSCURO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('elegir un tema y un modo cambia la app en vivo', (tester) async {
    await _pumpApp(tester);
    RegiTheme theme() =>
        RegiTheme.of(tester.element(find.byType(PokedexShell)));

    expect(theme().variant, RegiVariant.regirock);
    final frameBefore = theme().frame;

    await tester.tap(_hubButton('Ajustes'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('REGICE'));
    await tester.pumpAndSettle();
    expect(theme().variant, RegiVariant.regice);
    expect(theme().frame, isNot(frameBefore));
    expect(_checkIn('REGICE'), findsOneWidget);
    expect(_checkIn('REGIROCK'), findsNothing);

    final lightScreen = theme().screen;
    await tester.tap(find.text('OSCURO'));
    await tester.pumpAndSettle();
    expect(theme().screen, isNot(lightScreen));
    expect(
      Theme.of(tester.element(find.byType(PokedexShell))).brightness,
      Brightness.dark,
    );
    expect(_checkIn('OSCURO'), findsOneWidget);
    expect(_checkIn('CLARO'), findsNothing);
    expect(tester.takeException(), isNull);

    // La elección sigue al cerrar la ventana.
    await tester.tap(find.text('LISTO'));
    await tester.pumpAndSettle();
    expect(theme().variant, RegiVariant.regice);
  });

  testWidgets('Ajustes cabe en 320×568 con el texto al 200 %', (tester) async {
    await _pumpApp(tester, size: const Size(320, 568), textScale: 2);
    await tester.tap(_hubButton('Ajustes'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsDialog), findsOneWidget);
  });

  testWidgets(
    'la carcasa muestra el estado provisional en todas las pantallas',
    (tester) async {
      await _pumpApp(tester);

      expect(find.text('EN LÍNEA'), findsOneWidget);
      await tester.tap(_hubButton('Catálogo'));
      await tester.pumpAndSettle();
      expect(find.text('EN LÍNEA'), findsOneWidget);
    },
  );

  testWidgets('Inicio no desborda en 320×568 con el texto al 200 %', (
    tester,
  ) async {
    await _pumpApp(tester, size: const Size(320, 568), textScale: 2);

    expect(tester.takeException(), isNull);
    for (final label in [..._screens, 'Ajustes']) {
      expect(_hubButton(label), findsOneWidget);
    }
  });

  testWidgets('en pantalla estrecha los destinos siguen siendo tocables', (
    tester,
  ) async {
    await _pumpApp(tester, size: const Size(320, 568));

    // Los tres botones inferiores pueden quedar fuera de vista: se desplaza.
    await tester.ensureVisible(_hubButton('Equipos'));
    await tester.tap(_hubButton('Equipos'));
    await tester.pumpAndSettle();
    expect(find.text('Equipos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
