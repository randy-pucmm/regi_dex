import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/components/hex_choice.dart';
import 'package:regi_dex/ui/themes/regi_themes.dart';
import 'package:regi_dex/ui/tokens/contrast.dart';
import 'package:regi_dex/ui/tokens/regi_colors.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

Widget _host(Widget child, {double textScale = 1}) {
  return MaterialApp(
    theme: RegiThemes.build(RegiVariant.regirock, Brightness.light),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        backgroundColor: RegiInk.panel,
        body: Center(child: child),
      ),
    ),
  );
}

void main() {
  test('el borde de una opción sin elegir se distingue del fondo (≥ 3:1)', () {
    expect(
      contrastRatio(HexChoice.unselectedBorder, RegiInk.panel),
      greaterThanOrEqualTo(3),
    );
  });

  testWidgets('la opción elegida lleva «✓»; la otra no', (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HexChoice(label: 'Regice', selected: true, onPressed: () {}),
            HexChoice(label: 'Regirock', selected: false, onPressed: () {}),
          ],
        ),
      ),
    );

    expect(find.text('REGICE'), findsOneWidget);
    expect(find.text('REGIROCK'), findsOneWidget);
    // Un solo «✓»: el de la opción elegida.
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(HexChoice, 'REGICE'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
  });

  testWidgets('mide al menos 48 dp y responde al toque', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 150,
          child: HexChoice(
            label: 'Regieleki',
            selected: false,
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(HexChoice)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byType(HexChoice));
    expect(taps, 1);
  });

  testWidgets('relleno: la opción elegida es blanca con texto oscuro legible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 150,
          child: HexChoice(
            label: 'Claro',
            filled: true,
            selected: true,
            onPressed: () {},
          ),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(HexChoice),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, RegiInk.onShell);
    final style = tester.widget<Text>(find.text('CLARO')).style!;
    expect(
      contrastRatio(style.color!, material.color!),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('una opción se anuncia como botón seleccionado o no', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HexChoice(label: 'Regice', selected: true, onPressed: () {}),
            HexChoice(label: 'Regirock', selected: false, onPressed: () {}),
          ],
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Regice')),
      isSemantics(label: 'Regice', isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Regirock')),
      isSemantics(label: 'Regirock', isButton: true, isSelected: false),
    );
    handle.dispose();
  });

  testWidgets('una acción es un botón sin estado de selección', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 128,
          child: HexChoice(label: 'Listo', onPressed: () {}),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Listo')),
      isSemantics(
        label: 'Listo',
        isButton: true,
        hasTapAction: true,
        hasSelectedState: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('no desborda estrecho y con el texto al 200 %', (tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 110,
          child: HexChoice(
            label: 'Regigigas',
            selected: true,
            leading: const SizedBox.square(dimension: 18),
            onPressed: () {},
          ),
        ),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
