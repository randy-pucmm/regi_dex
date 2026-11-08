import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/components/regi_dialog.dart';
import 'package:regi_dex/ui/themes/regi_themes.dart';
import 'package:regi_dex/ui/tokens/regi_colors.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

Widget _app({
  required Widget body,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: RegiThemes.build(RegiVariant.regirock, brightness),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
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

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra el título en mayúsculas y el contenido', (tester) async {
    _setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(_app(body: const Text('cuerpo')));
    await _open(tester);

    expect(find.text('AJUSTES'), findsOneWidget);
    expect(find.text('cuerpo'), findsOneWidget);
  });

  testWidgets('es oscura en modo claro y en modo oscuro', (tester) async {
    for (final brightness in Brightness.values) {
      _setScreen(tester, const Size(390, 844));
      await tester.pumpWidget(
        _app(body: const Text('cuerpo'), brightness: brightness),
      );
      await _open(tester);

      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.backgroundColor, RegiInk.panel);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('se cierra tocando fuera', (tester) async {
    _setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(_app(body: const Text('cuerpo')));
    await _open(tester);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(RegiDialog), findsNothing);
  });

  testWidgets('se anuncia como ventana con su título', (tester) async {
    _setScreen(tester, const Size(390, 844));
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(body: const Text('cuerpo')));
    await _open(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Ajustes')),
      isSemantics(label: 'Ajustes', scopesRoute: true, namesRoute: true),
    );
    handle.dispose();
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'con mucho contenido se desplaza en vez de desbordar (${brightness.name})',
      (tester) async {
        _setScreen(tester, const Size(320, 480));
        await tester.pumpWidget(
          _app(
            brightness: brightness,
            textScale: 2,
            body: Column(
              children: [for (var i = 0; i < 30; i++) Text('línea $i')],
            ),
          ),
        );
        await _open(tester);

        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
      },
    );
  }
}
