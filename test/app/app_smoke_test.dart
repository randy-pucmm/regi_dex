import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/app.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/app/shell_status.dart';
import 'package:regi_dex/core/connectivity/service_status.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/sync/sync_status.dart';
import 'package:regi_dex/features/favorites/presentation/favorites_page.dart';
import 'package:regi_dex/features/pokemon/presentation/catalog_page.dart';
import 'package:regi_dex/features/settings/presentation/settings_dialog.dart';
import 'package:regi_dex/features/team_builder/presentation/team_builder_page.dart';
import 'package:regi_dex/features/trivia/presentation/trivia_page.dart';
import 'package:regi_dex/ui/components/hex_choice.dart';
import 'package:regi_dex/ui/components/hub_buttons.dart';
import 'package:regi_dex/ui/components/led_eyes.dart';
import 'package:regi_dex/ui/components/pokedex_shell.dart';
import 'package:regi_dex/ui/components/shell_status_band.dart';
import 'package:regi_dex/ui/components/status_led.dart';
import 'package:regi_dex/ui/themes/regi_theme.dart';
import 'package:regi_dex/ui/tokens/led_state.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

import '../core/connectivity/connectivity_fakes.dart';
import '../core/database/database_test_helpers.dart';
import '../features/pokemon/fake_pokemon_repository.dart';
import '../helpers/ui_test_helpers.dart';

/// Destinos de Inicio que abren una pantalla (Ajustes abre una ventana).
const _screens = ['Catálogo', 'Favoritos', 'Equipos', 'Trivia'];

final _screenPages = <String, Type>{
  'Catálogo': CatalogPage,
  'Favoritos': FavoritesPage,
  'Equipos': TeamBuilderPage,
  'Trivia': TriviaPage,
};

/// Conexión estable por defecto: PokéAPI responde por Wi-Fi.
const _online = ConnectivitySnapshot(
  status: ServiceStatus.online,
  networkKind: NetworkKind.wifi,
);

/// Hay red pero PokéAPI no responde.
const _down = ConnectivitySnapshot(
  status: ServiceStatus.servicioNoDisponible,
  networkKind: NetworkKind.wifi,
  lastFailure: TimeoutFailure(),
);

Future<void> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  ConnectivitySnapshot connectivity = _online,
  Stream<ConnectivitySnapshot>? connectivityStream,
  SyncStatus sync = SyncStatus.inactiva,
  DateTime? lastSync,
  FakeHealthChecker? health,
}) async {
  useScreen(tester, size, textScale: textScale);
  reduceMotion(tester);
  final db = createTestDatabase();
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        networkSourceProvider.overrideWithValue(FakeNetworkSource()),
        healthCheckerProvider.overrideWithValue(health ?? FakeHealthChecker()),
        serviceStatusProvider.overrideWith(
          (ref) => connectivityStream ?? Stream.value(connectivity),
        ),
        syncStatusProvider.overrideWith((ref) => Stream.value(sync)),
        lastSyncAtProvider.overrideWith((ref) => Stream.value(lastSync)),
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
      expect(find.byType(_screenPages[label]!), findsOneWidget);
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

  testWidgets('las muestras de Ajustes siguen el modo: en oscuro, los shiny', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(_hubButton('Ajustes'));
    await tester.pumpAndSettle();

    Color swatch(RegiVariant variant) {
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.widgetWithText(
                HexChoice,
                variant.displayName.toUpperCase(),
              ),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is DecoratedBox &&
                    w.decoration is BoxDecoration &&
                    (w.decoration as BoxDecoration).shape == BoxShape.circle,
              ),
            )
            .first,
      );
      return (box.decoration as BoxDecoration).color!;
    }

    Color frame(RegiVariant variant, Brightness brightness) =>
        RegiTheme.forVariant(variant, brightness).frame;

    for (final variant in RegiVariant.values) {
      expect(swatch(variant), frame(variant, Brightness.light));
    }

    await tester.tap(find.text('OSCURO'));
    await tester.pumpAndSettle();

    for (final variant in RegiVariant.values) {
      expect(
        swatch(variant),
        frame(variant, Brightness.dark),
        reason: variant.displayName,
      );
    }
    // Los dos que antes seguían igual en oscuro ya no lo hacen.
    expect(
      swatch(RegiVariant.regieleki),
      isNot(frame(RegiVariant.regieleki, Brightness.light)),
    );
    expect(
      swatch(RegiVariant.regidrago),
      isNot(frame(RegiVariant.regidrago, Brightness.light)),
    );
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

  testWidgets('la cabecera no lleva el texto del estado fijo: está en el '
      'desplegable del LED', (tester) async {
    await _pumpApp(tester, lastSync: DateTime(2026, 11, 6, 10, 42));

    // Fijo en la cabecera: la hora, los indicadores y el LED.
    expect(find.text('ACT. 10:42'), findsOneWidget);
    expect(find.text('RED'), findsOneWidget);
    expect(find.byType(StatusLed), findsOneWidget);
    // Lo demás queda recogido hasta tocar el LED.
    expect(find.byType(ShellStatusBand), findsNothing);
    expect(find.text('EN LÍNEA'), findsNothing);

    await tester.tap(find.byType(StatusLed));
    await tester.pumpAndSettle();

    expect(find.text('EN LÍNEA'), findsOneWidget);
    expect(find.text('Datos remotos · actualizado 10:42'), findsWidgets);
  });

  testWidgets('el LED y el desplegable están en todas las pantallas', (
    tester,
  ) async {
    await _pumpApp(tester, lastSync: DateTime(2026, 11, 6, 10, 42));

    for (final label in _screens) {
      await tester.tap(_hubButton(label));
      await tester.pumpAndSettle();
      expect(find.byType(StatusLed), findsOneWidget, reason: label);

      await tester.tap(find.byType(StatusLed));
      await tester.pumpAndSettle();
      expect(find.text('EN LÍNEA'), findsOneWidget, reason: label);

      // Recogerlo con «atrás» no cambia de pantalla.
      await tester.tapAt(const Offset(4, 840));
      await tester.pumpAndSettle();
      expect(find.text('EN LÍNEA'), findsNothing, reason: label);
      expect(find.byType(_screenPages[label]!), findsOneWidget, reason: label);

      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
    }
  });

  group('estados del LED en la carcasa', () {
    final cases = <(String, ConnectivitySnapshot, SyncStatus, String, String)>[
      (
        'sin conexión',
        const ConnectivitySnapshot(status: ServiceStatus.offline),
        SyncStatus.inactiva,
        'SIN CONEXIÓN',
        'Datos locales · última sync 09:15',
      ),
      (
        'servicio no disponible',
        const ConnectivitySnapshot(
          status: ServiceStatus.servicioNoDisponible,
          networkKind: NetworkKind.wifi,
          lastFailure: TimeoutFailure(),
        ),
        SyncStatus.inactiva,
        'SERVICIO NO DISPONIBLE',
        'Red activa, API sin respuesta · datos locales',
      ),
      (
        'sincronizando',
        _online,
        SyncStatus.sincronizando,
        'SINCRONIZANDO',
        'En línea · puedes seguir navegando',
      ),
      (
        'verificando al arrancar',
        const ConnectivitySnapshot(),
        SyncStatus.inactiva,
        'VERIFICANDO',
        'Comprobando la conexión · datos locales',
      ),
    ];

    for (final (name, connectivity, sync, title, subtitle) in cases) {
      testWidgets(name, (tester) async {
        await _pumpApp(
          tester,
          connectivity: connectivity,
          sync: sync,
          lastSync: DateTime(2026, 11, 6, 9, 15),
        );

        await tester.tap(find.byType(StatusLed));
        await tester.pumpAndSettle();

        expect(find.text(title), findsOneWidget);
        expect(find.text(subtitle), findsOneWidget);
        expect(
          tester.widget<ShellStatusBand>(find.byType(ShellStatusBand)).progress,
          sync == SyncStatus.sincronizando ||
              connectivity.status == ServiceStatus.verificando,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ojos del octógono de Inicio', () {
    Finder octagonEyes() => find.descendant(
      of: find.byType(OctagonHubButton),
      matching: find.byType(LedEyes),
    );

    final sameAsLed = <(String, ConnectivitySnapshot, SyncStatus, LedState)>[
      ('en línea', _online, SyncStatus.inactiva, LedState.online),
      ('servicio caído', _down, SyncStatus.inactiva, LedState.down),
      ('sincronizando', _online, SyncStatus.sincronizando, LedState.sync),
    ];
    for (final (name, connectivity, sync, expected) in sameAsLed) {
      testWidgets('muestran el mismo estado que el LED: $name', (tester) async {
        await _pumpApp(tester, connectivity: connectivity, sync: sync);

        expect(tester.widget<LedEyes>(octagonEyes()).state, expected);
        expect(
          tester.widget<StatusLed>(find.byType(StatusLed)).state,
          expected,
        );
      });
    }

    testWidgets('cambian a medida que cambia la conexión', (tester) async {
      final status = StreamController<ConnectivitySnapshot>();
      addTearDown(status.close);
      await _pumpApp(tester, connectivityStream: status.stream);
      status.add(_online);
      await tester.pumpAndSettle();
      expect(tester.widget<LedEyes>(octagonEyes()).state, LedState.online);

      status.add(const ConnectivitySnapshot(status: ServiceStatus.offline));
      await tester.pumpAndSettle();
      expect(tester.widget<LedEyes>(octagonEyes()).state, LedState.offline);
      expect(
        tester.widget<StatusLed>(find.byType(StatusLed)).semanticsLabel,
        startsWith('Estado de conexión: Sin conexión.'),
      );
    });
  });

  group('LED de la cabecera', () {
    testWidgets('es un botón de al menos 48 dp con su etiqueta', (
      tester,
    ) async {
      await _pumpApp(tester, lastSync: DateTime(2026, 11, 6, 10, 42));

      expect(
        tester.getSize(find.byType(StatusLed)),
        greaterThanOrEqualTo(const Size(48, 48)),
      );
      expect(
        find.bySemanticsLabel(
          'Estado de conexión: En línea. Datos remotos · actualizado 10:42',
        ),
        findsOneWidget,
      );
    });

    testWidgets('al tocarlo abre el detalle y tocar fuera lo cierra', (
      tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.byType(StatusLed));
      await tester.pumpAndSettle();

      expect(find.text('SINCRONIZAR AHORA'), findsOneWidget);
      expect(find.text('Activa (Wi-Fi)'), findsOneWidget);
      expect(find.text('Disponible'), findsOneWidget);

      await tester.tapAt(const Offset(4, 840));
      await tester.pumpAndSettle();
      expect(find.text('SINCRONIZAR AHORA'), findsNothing);
    });

    testWidgets('«Sincronizar ahora» vuelve a comprobar PokéAPI y cierra', (
      tester,
    ) async {
      final health = FakeHealthChecker();
      await _pumpApp(tester, health: health);
      await tester.tap(find.byType(StatusLed));
      await tester.pumpAndSettle();
      final before = health.calls;

      await tester.tap(find.text('SINCRONIZAR AHORA'));
      await tester.pumpAndSettle();

      expect(find.text('SINCRONIZAR AHORA'), findsNothing);
      expect(health.calls, greaterThan(before));
    });

    testWidgets('sin conexión «Sincronizar ahora» queda deshabilitado', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        connectivity: const ConnectivitySnapshot(status: ServiceStatus.offline),
      );
      await tester.tap(find.byType(StatusLed));
      await tester.pumpAndSettle();

      expect(
        tester.widget<HexButton>(find.byType(HexButton).last).onPressed,
        isNull,
      );
      expect(find.text('Sin conexión'), findsWidgets);
    });

    testWidgets('el detalle cabe en 320×568 con el texto al 200 %', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        size: const Size(320, 568),
        textScale: 2,
        connectivity: ConnectivitySnapshot(
          status: ServiceStatus.servicioNoDisponible,
          networkKind: NetworkKind.wifi,
          lastFailure: const TimeoutFailure(),
          nextRetryAt: DateTime.now().add(const Duration(seconds: 30)),
        ),
      );
      await tester.tap(find.byType(StatusLed));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('SINCRONIZAR AHORA'), findsOneWidget);
    });
  });

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
