import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/components/stat_bar.dart';
import 'package:regi_dex/ui/components/type_chip.dart';
import 'package:regi_dex/ui/tokens/regi_colors.dart';

import '../../helpers/ui_test_helpers.dart';

void main() {
  group('TypeChip', () {
    testWidgets(
      'muestra la etiqueta en mayúsculas y la anuncia como «Tipo X»',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          regiHost(const TypeChip(typeKey: 'ice', label: 'Hielo')),
        );

        expect(find.text('HIELO'), findsOneWidget);
        expect(find.bySemanticsLabel('Tipo Hielo'), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets('con onTap es un botón de al menos 48 dp', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        regiHost(
          TypeChip(typeKey: 'steel', label: 'Acero', onTap: () => taps++),
        ),
      );

      final size = tester.getSize(find.byType(InkWell));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      await tester.tap(find.byType(InkWell));
      expect(taps, 1);
    });

    testWidgets('no desborda con el texto al 200 %', (tester) async {
      await tester.pumpWidget(
        regiHost(
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
        regiHost(
          const StatBar(stat: RegiStat.attack, value: 75),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('ATAQUE'), findsOneWidget);
      expect(find.text('75'), findsOneWidget);
      expect(find.bySemanticsLabel('ATAQUE: 75 de 255'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('las seis estadísticas se pintan sin desbordar', (
      tester,
    ) async {
      await tester.pumpWidget(
        regiHost(
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
}
