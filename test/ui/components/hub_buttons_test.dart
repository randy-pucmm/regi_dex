import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/components/hub_buttons.dart';
import 'package:regi_dex/ui/themes/regi_themes.dart';
import 'package:regi_dex/ui/tokens/contrast.dart';
import 'package:regi_dex/ui/tokens/regi_colors.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

Widget _host(Widget child, {double textScale = 1}) {
  return MaterialApp(
    theme: RegiThemes.build(RegiVariant.regirock, Brightness.light),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  test('los colores de destino se leen sobre el fondo oscuro del botón', () {
    for (final color in [
      RegiHubColors.favorites,
      RegiHubColors.trivia,
      RegiHubColors.teams,
    ]) {
      expect(contrastRatio(color, RegiInk.shell), greaterThanOrEqualTo(4.5));
    }
  });

  group('HexButton', () {
    testWidgets('muestra el nombre en mayúsculas y responde al toque', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          HexButton(
            label: 'Favoritos',
            color: RegiHubColors.favorites,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.text('FAVORITOS'), findsOneWidget);
      expect(
        tester.getSize(find.byType(HexButton)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byType(HexButton));
      expect(taps, 1);
    });

    testWidgets('se anuncia como botón con su nombre', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          HexButton(
            label: 'Trivia',
            color: RegiHubColors.trivia,
            onPressed: () {},
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(HexButton)),
        isSemantics(label: 'Trivia', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('no desborda estrecho y con el texto al 200 %', (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 96,
            child: HexButton(
              label: 'Favoritos',
              color: RegiHubColors.favorites,
              onPressed: () {},
            ),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('HexIconButton', () {
    testWidgets('mide al menos 48 dp, se anuncia y responde', (tester) async {
      var taps = 0;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          HexIconButton(
            icon: Icons.tune,
            label: 'Ajustes',
            labelColor: Colors.white,
            onPressed: () => taps++,
          ),
        ),
      );

      final size = tester.getSize(find.byType(HexIconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(find.text('AJUSTES'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(HexIconButton)),
        isSemantics(label: 'Ajustes', isButton: true, hasTapAction: true),
      );

      await tester.tap(find.byType(HexIconButton));
      expect(taps, 1);
      handle.dispose();
    });
  });

  group('OctagonHubButton', () {
    testWidgets('muestra el nombre, el contenido y responde al toque', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          OctagonHubButton(
            label: 'Catálogo',
            onPressed: () => taps++,
            child: const Text('ojos'),
          ),
        ),
      );

      expect(find.text('CATÁLOGO'), findsOneWidget);
      expect(find.text('ojos'), findsOneWidget);
      await tester.tap(find.text('CATÁLOGO'));
      expect(taps, 1);
    });

    test('el bisel hace regular al octógono: lado diagonal = lado recto', () {
      const size = 240.0;
      final chamfer = size * OctagonHubButton.chamferRatio;
      final flat = size - 2 * chamfer;
      expect(chamfer * math.sqrt2, closeTo(flat, 1e-9));
    });

    testWidgets('es cuadrado', (tester) async {
      await tester.pumpWidget(
        _host(OctagonHubButton(label: 'Catálogo', size: 200, onPressed: () {})),
      );
      final box = tester.getSize(find.byType(OctagonHubButton));
      expect(box.width, box.height);
    });

    testWidgets('se anuncia como botón y no desborda a 150 de ancho al 200 %', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          OctagonHubButton(label: 'Catálogo', size: 150, onPressed: () {}),
          textScale: 2,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSemantics(find.byType(OctagonHubButton)),
        isSemantics(label: 'Catálogo', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });
  });
}
