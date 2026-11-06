import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/components/hex_choice.dart';
import 'package:regi_dex/ui/tokens/regi_colors.dart';

import '../../helpers/ui_test_helpers.dart';

Widget _host(Widget child, {double textScale = 1}) =>
    regiHost(child, textScale: textScale, background: RegiInk.panel);

void main() {
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

  testWidgets('se anuncia como opción elegida o no, o como acción sin estado', (
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
            HexChoice(label: 'Listo', onPressed: () {}),
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
