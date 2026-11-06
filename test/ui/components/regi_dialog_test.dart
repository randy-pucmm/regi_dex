import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/components/regi_dialog.dart';
import 'package:regi_dex/ui/themes/regi_themes.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

import '../../helpers/ui_test_helpers.dart';

Widget _app(Widget body) {
  return MaterialApp(
    theme: RegiThemes.build(RegiVariant.regirock, Brightness.light),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierLabel: 'Cerrar',
              builder: (_) => RegiDialog(title: 'Ajustes', child: body),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester, Widget body) async {
  await tester.pumpWidget(_app(body));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra el título en mayúsculas y el contenido', (tester) async {
    useScreen(tester, const Size(390, 844));
    await _open(tester, const Text('cuerpo'));

    expect(find.text('AJUSTES'), findsOneWidget);
    expect(find.text('cuerpo'), findsOneWidget);
  });

  testWidgets('se cierra tocando fuera', (tester) async {
    useScreen(tester, const Size(390, 844));
    await _open(tester, const Text('cuerpo'));

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(RegiDialog), findsNothing);
  });

  testWidgets('se anuncia como ventana con su título', (tester) async {
    useScreen(tester, const Size(390, 844));
    final handle = tester.ensureSemantics();
    await _open(tester, const Text('cuerpo'));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Ajustes')),
      isSemantics(label: 'Ajustes', scopesRoute: true, namesRoute: true),
    );
    handle.dispose();
  });

  testWidgets('con mucho contenido se desplaza en vez de desbordar', (
    tester,
  ) async {
    useScreen(tester, const Size(320, 480), textScale: 2);
    await _open(
      tester,
      Column(children: [for (var i = 0; i < 30; i++) Text('línea $i')]),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
