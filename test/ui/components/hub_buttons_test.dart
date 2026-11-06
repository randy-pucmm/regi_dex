import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/components/hub_buttons.dart';
import 'package:regi_dex/ui/tokens/regi_colors.dart';

import '../../helpers/ui_test_helpers.dart';

void main() {
  group('HexButton', () {
    testWidgets('muestra el nombre en mayúsculas y responde al toque', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        regiHost(
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
        regiHost(
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
        regiHost(
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

    testWidgets('sin onPressed queda deshabilitado y sin toque', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        regiHost(
          const HexButton(
            label: 'Sincronizar ahora',
            color: RegiHubColors.trivia,
            onPressed: null,
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(HexButton)),
        isSemantics(
          label: 'Sincronizar ahora',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      await tester.tap(find.byType(HexButton), warnIfMissed: false);
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  });

  testWidgets('HexIconButton mide al menos 48 dp, se anuncia y responde', (
    tester,
  ) async {
    var taps = 0;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      regiHost(
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
    expect(
      tester.getSemantics(find.byType(HexIconButton)),
      isSemantics(label: 'Ajustes', isButton: true, hasTapAction: true),
    );

    await tester.tap(find.byType(HexIconButton));
    expect(taps, 1);
    handle.dispose();
  });

  group('OctagonHubButton', () {
    testWidgets('muestra el nombre y el contenido, y responde al toque', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        regiHost(
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

    testWidgets('se anuncia como botón y no desborda a 150 de ancho al 200 %', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        regiHost(
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
