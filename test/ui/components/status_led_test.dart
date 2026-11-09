import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/components/hub_buttons.dart';
import 'package:regi_dex/ui/components/shell_status_band.dart';
import 'package:regi_dex/ui/components/status_led.dart';
import 'package:regi_dex/ui/components/status_popover.dart';
import 'package:regi_dex/ui/themes/regi_themes.dart';
import 'package:regi_dex/ui/tokens/led_state.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

import '../../helpers/ui_test_helpers.dart';

const _label =
    'Estado de conexión: Servicio no disponible. '
    'Red activa, API sin respuesta · datos locales';

const _subtitle = 'Red activa, API sin respuesta · datos locales';

StatusDetails _details({VoidCallback? onSyncNow}) => StatusDetails(
  title: 'Servicio no disponible',
  subtitle: _subtitle,
  message: 'Tu red funciona, pero PokéAPI no responde.',
  rows: const [
    StatusRow('Red', 'Activa (Wi-Fi)'),
    StatusRow('PokéAPI', 'Sin respuesta (timeout)'),
    StatusRow('Datos', 'Locales · última sync 09:15'),
    StatusRow('Reintento', 'en 30 s'),
  ],
  onSyncNow: onSyncNow,
);

Widget _host(StatusDetails details, {double lensSize = 68}) {
  return MaterialApp(
    theme: RegiThemes.build(RegiVariant.regirock, Brightness.dark),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: lensSize,
            height: lensSize,
            child: StatusLed(
              state: LedState.down,
              semanticsLabel: _label,
              details: details,
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byType(StatusLed));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('es un botón de al menos 48 dp', (tester) async {
    reduceMotion(tester);
    await tester.pumpWidget(_host(_details(), lensSize: 48));

    final size = tester.getSize(find.byType(StatusLed));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('se anuncia como botón con el estado y cómo abrir el detalle', (
    tester,
  ) async {
    reduceMotion(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(_details()));

    expect(
      tester.getSemantics(find.byType(StatusLed)),
      isSemantics(
        label: _label,
        hint: 'Ver detalle de la conexión',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('al tocarlo despliega la banda y el detalle bajo el lente', (
    tester,
  ) async {
    reduceMotion(tester);
    await tester.pumpWidget(_host(_details()));
    expect(find.byType(ShellStatusBand), findsNothing);

    await _open(tester);

    expect(find.text('SERVICIO NO DISPONIBLE'), findsOneWidget);
    expect(find.text(_subtitle), findsOneWidget);
    expect(find.text('Tu red funciona, pero PokéAPI no responde.'), findsOne);
    for (final label in ['RED', 'POKÉAPI', 'DATOS', 'REINTENTO']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Activa (Wi-Fi)'), findsOneWidget);
    expect(find.text('SINCRONIZAR AHORA'), findsOneWidget);

    final lensBottom = tester.getBottomLeft(find.byType(StatusLed)).dy;
    final bandBottom = tester.getBottomLeft(find.byType(ShellStatusBand)).dy;
    final rowsTop = tester.getTopLeft(find.byType(Table)).dy;
    expect(
      tester.getTopLeft(find.byType(ShellStatusBand)).dy,
      greaterThan(lensBottom),
    );
    expect(
      bandBottom,
      lessThan(rowsTop),
      reason: 'la banda va antes del detalle',
    );
  });

  testWidgets('se despliega hacia abajo con animación', (tester) async {
    await tester.pumpWidget(_host(_details()));
    await tester.tap(find.byType(StatusLed));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final starting = tester.getSize(find.byType(SizeTransition)).height;

    await tester.pump(const Duration(milliseconds: 400));
    final finished = tester.getSize(find.byType(SizeTransition)).height;

    expect(starting, lessThan(finished));
    // El borde de arriba no se mueve: crece desde el LED hacia abajo.
    expect(
      tester.getTopLeft(find.byType(SizeTransition)).dy,
      greaterThan(tester.getBottomLeft(find.byType(StatusLed)).dy),
    );
  });

  testWidgets('tocar fuera lo cierra sin acción', (tester) async {
    reduceMotion(tester);
    var syncs = 0;
    await tester.pumpWidget(_host(_details(onSyncNow: () => syncs++)));
    await _open(tester);

    await tester.tapAt(const Offset(780, 580));
    await tester.pumpAndSettle();

    expect(find.text('SERVICIO NO DISPONIBLE'), findsNothing);
    expect(syncs, 0);
  });

  testWidgets('«Sincronizar ahora» avisa y cierra el detalle', (tester) async {
    reduceMotion(tester);
    var syncs = 0;
    await tester.pumpWidget(_host(_details(onSyncNow: () => syncs++)));
    await _open(tester);

    await tester.tap(find.text('SINCRONIZAR AHORA'));
    await tester.pumpAndSettle();

    expect(syncs, 1);
    expect(find.text('SERVICIO NO DISPONIBLE'), findsNothing);
  });

  testWidgets('sin acción disponible el botón está deshabilitado y no cierra', (
    tester,
  ) async {
    reduceMotion(tester);
    await tester.pumpWidget(_host(_details()));
    await _open(tester);

    expect(tester.widget<HexButton>(find.byType(HexButton)).onPressed, isNull);
    await tester.tap(find.text('SINCRONIZAR AHORA'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('SERVICIO NO DISPONIBLE'), findsOneWidget);
  });

  testWidgets(
    'el detalle se anuncia como ventana y sus filas se leen enteras',
    (tester) async {
      reduceMotion(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(_details()));
      await _open(tester);

      expect(find.bySemanticsLabel('Servicio no disponible'), findsOneWidget);
      expect(
        find.bySemanticsLabel('PokéAPI: Sin respuesta (timeout)'),
        findsOne,
      );
      handle.dispose();
    },
  );

  testWidgets('cabe en 320×568 con el texto al 200 % y se desplaza', (
    tester,
  ) async {
    reduceMotion(tester);
    useScreen(tester, const Size(320, 568), textScale: 2);
    await tester.pumpWidget(_host(_details()));

    await _open(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('SINCRONIZAR AHORA'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
