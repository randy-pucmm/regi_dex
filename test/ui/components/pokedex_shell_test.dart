import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/components/hexagon_border.dart';
import 'package:regi_dex/ui/components/pokedex_shell.dart';
import 'package:regi_dex/ui/components/shell_status_band.dart';
import 'package:regi_dex/ui/themes/regi_themes.dart';
import 'package:regi_dex/ui/tokens/regi_colors.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

const _indicators = [
  ShellIndicator(
    label: 'RED',
    color: RegiLedColors.online,
    semanticsLabel: 'Red: conectada',
  ),
  ShellIndicator(
    label: 'API',
    color: RegiLedColors.online,
    semanticsLabel: 'API: disponible',
  ),
  ShellIndicator(
    label: 'DATOS',
    color: RegiLedColors.online,
    semanticsLabel: 'Datos: remotos',
  ),
];

Widget _shell({
  Brightness brightness = Brightness.dark,
  RegiVariant variant = RegiVariant.regirock,
  double textScale = 1,
  VoidCallback? onHome,
  Widget child = const Text('contenido'),
}) {
  return MaterialApp(
    theme: RegiThemes.build(variant, brightness),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: PokedexShell(
      updatedLabel: 'ACT. 10:42',
      indicators: _indicators,
      lens: const ShellLens(ringColor: RegiLedColors.online, child: SizedBox()),
      statusBand: const ShellStatusBand(
        color: RegiLedColors.online,
        title: 'En línea',
        subtitle: 'Datos remotos · actualizado 10:42',
      ),
      bottomBar: onHome == null ? null : ShellHomeButton(onPressed: onHome),
      child: child,
    ),
  );
}

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('HexagonBorder', () {
    const rect = Rect.fromLTWH(0, 0, 100, 40);

    test('vertical: los vértices están arriba y abajo', () {
      final path = const HexagonBorder().getOuterPath(rect);
      expect(path.contains(const Offset(50, 20)), isTrue);
      expect(path.contains(const Offset(2, 2)), isFalse);
      expect(path.contains(const Offset(98, 38)), isFalse);
      expect(path.getBounds(), rect);
    });

    test('horizontal: los vértices están a los lados', () {
      final path = const HexagonBorder(
        pointAxis: Axis.horizontal,
        depth: 15,
      ).getOuterPath(rect);
      expect(path.contains(const Offset(50, 2)), isTrue);
      expect(path.contains(const Offset(2, 2)), isFalse);
      expect(path.contains(const Offset(1, 20)), isTrue);
      expect(path.getBounds(), rect);
    });

    test('el camino interior se reduce con el grosor del borde', () {
      const border = HexagonBorder(side: BorderSide(width: 4));
      expect(border.getInnerPath(rect).getBounds().width, lessThan(100));
      expect(border.dimensions, const EdgeInsets.all(4));
    });

    test('copyWith y scale conservan el eje', () {
      const border = HexagonBorder(pointAxis: Axis.horizontal, depth: 10);
      expect(border.copyWith().pointAxis, Axis.horizontal);
      expect((border.scale(2) as HexagonBorder).depth, 10);
      expect(border, border.copyWith());
    });
  });

  group('PokedexShell', () {
    testWidgets('muestra cabecera, título, banda y contenido', (tester) async {
      _setScreen(tester, const Size(390, 844));
      await tester.pumpWidget(_shell());

      expect(find.text('ACT. 10:42'), findsOneWidget);
      for (final label in ['RED', 'API', 'DATOS']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final letter in ['R', 'E', 'G', 'I', 'D', 'X']) {
        expect(find.text(letter), findsWidgets);
      }
      expect(find.text('POKÉDEX NACIONAL · 1 025'), findsOneWidget);
      expect(find.text('EN LÍNEA'), findsOneWidget);
      expect(find.text('Datos remotos · actualizado 10:42'), findsOneWidget);
      expect(find.text('contenido'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin barra inferior no muestra «Inicio»', (tester) async {
      _setScreen(tester, const Size(390, 844));
      await tester.pumpWidget(_shell());
      expect(find.text('Inicio'), findsNothing);
    });

    testWidgets('el botón «Inicio» mide ≥ 48 dp y responde al toque', (
      tester,
    ) async {
      _setScreen(tester, const Size(390, 844));
      var taps = 0;
      await tester.pumpWidget(_shell(onHome: () => taps++));

      final size = tester.getSize(find.byType(ShellHomeButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      await tester.tap(find.text('Inicio'));
      expect(taps, 1);
    });

    testWidgets('expone título, indicadores y banda a los lectores', (
      tester,
    ) async {
      _setScreen(tester, const Size(390, 844));
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_shell(onHome: () {}));

      expect(
        find.bySemanticsLabel('RegiDex, Pokédex Nacional, 1025'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Red: conectada'), findsOneWidget);
      expect(find.bySemanticsLabel('API: disponible'), findsOneWidget);
      expect(find.bySemanticsLabel('Datos: remotos'), findsOneWidget);
      expect(
        find.bySemanticsLabel('En línea. Datos remotos · actualizado 10:42'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Inicio'), findsOneWidget);
      handle.dispose();
    });

    for (final variant in RegiVariant.values) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'se construye sin desbordar: ${variant.displayName} ${brightness.name}',
          (tester) async {
            _setScreen(tester, const Size(390, 844));
            await tester.pumpWidget(
              _shell(variant: variant, brightness: brightness, onHome: () {}),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('no desborda en 320×568 con el texto al 200 %', (tester) async {
      _setScreen(tester, const Size(320, 568));
      await tester.pumpWidget(_shell(textScale: 2, onHome: () {}));
      expect(tester.takeException(), isNull);
      expect(find.text('contenido'), findsOneWidget);
    });
  });

  group('ShellStatusBand', () {
    testWidgets('con onTap es un botón accesible', (tester) async {
      var taps = 0;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: RegiThemes.build(RegiVariant.regirock, Brightness.dark),
          home: Scaffold(
            body: ShellStatusBand(
              color: RegiLedColors.sync,
              title: 'Sincronizando',
              subtitle: 'En línea',
              onTap: () => taps++,
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(ShellStatusBand)),
        isSemantics(isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSize(find.byType(ShellStatusBand)).height,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(find.byType(ShellStatusBand));
      expect(taps, 1);
      handle.dispose();
    });
  });
}
