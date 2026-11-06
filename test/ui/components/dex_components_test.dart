import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/components/dex_screen.dart';
import 'package:regi_dex/ui/components/stat_bar.dart';
import 'package:regi_dex/ui/components/type_chip.dart';
import 'package:regi_dex/ui/themes/regi_theme.dart';
import 'package:regi_dex/ui/themes/regi_themes.dart';
import 'package:regi_dex/ui/tokens/contrast.dart';
import 'package:regi_dex/ui/tokens/regi_colors.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

Widget _host(
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: RegiThemes.build(RegiVariant.regirock, brightness),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('TypeChip', () {
    testWidgets('muestra la etiqueta en mayúsculas con texto legible', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const TypeChip(typeKey: 'rock', label: 'Roca')),
      );

      expect(find.text('ROCA'), findsOneWidget);
      final style = tester.widget<Text>(find.text('ROCA')).style!;
      expect(
        contrastRatio(style.color!, RegiTypeColors.of('rock')),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('expone «Tipo X» a los lectores de pantalla', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const TypeChip(typeKey: 'ice', label: 'Hielo')),
      );

      expect(find.bySemanticsLabel('Tipo Hielo'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('con onTap es un botón de al menos 48 dp', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(TypeChip(typeKey: 'steel', label: 'Acero', onTap: () => taps++)),
      );

      final size = tester.getSize(find.byType(InkWell));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      await tester.tap(find.byType(InkWell));
      expect(taps, 1);
    });

    testWidgets('no desborda con el texto al 200 %', (tester) async {
      await tester.pumpWidget(
        _host(
          const TypeChip(typeKey: 'fighting', label: 'Lucha'),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('StatBar', () {
    test('la fracción se acota entre 0 y 1', () {
      const hp = RegiStat.hp;
      expect(const StatBar(stat: hp, value: 0).fraction, 0);
      expect(const StatBar(stat: hp, value: 255).fraction, 1);
      expect(const StatBar(stat: hp, value: 400).fraction, 1);
      expect(const StatBar(stat: hp, value: -5).fraction, 0);
      expect(
        const StatBar(stat: hp, value: 80).fraction,
        closeTo(80 / 255, 1e-9),
      );
      expect(const StatBar(stat: hp, value: 10, max: 0).fraction, 0);
    });

    testWidgets('muestra etiqueta y valor y los describe juntos', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const StatBar(stat: RegiStat.attack, value: 75),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('ATAQUE'), findsOneWidget);
      expect(find.text('75'), findsOneWidget);
      expect(find.bySemanticsLabel('ATAQUE: 75 de 255'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('la barra ocupa la fracción del valor', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 200,
            child: StatBar(stat: RegiStat.speed, value: 51),
          ),
        ),
      );

      final fill = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(fill.widthFactor, closeTo(0.2, 1e-9));
    });

    testWidgets('las seis estadísticas se pintan sin desbordar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final stat in RegiStat.values)
                SizedBox(width: 56, child: StatBar(stat: stat, value: 100)),
            ],
          ),
          brightness: Brightness.dark,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(StatBar), findsNWidgets(6));
    });
  });

  group('DexScreen', () {
    testWidgets('pinta el fondo del tema y redondea solo la esquina inferior '
        'derecha', (tester) async {
      await tester.pumpWidget(_host(const DexScreen(child: Text('contenido'))));

      expect(find.text('contenido'), findsOneWidget);
      final regi = RegiTheme.of(tester.element(find.byType(DexScreen)));
      final outer = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(DexScreen),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = outer.decoration as BoxDecoration;
      expect(decoration.color, regi.screen);

      final radius = decoration.borderRadius! as BorderRadius;
      expect(radius.bottomRight, const Radius.circular(DexScreen.cornerRadius));
      expect(radius.topLeft, Radius.zero);
      expect(radius.topRight, Radius.zero);
      expect(radius.bottomLeft, Radius.zero);
    });
  });
}
