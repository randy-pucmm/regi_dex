import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/components/led_eyes.dart';
import 'package:regi_dex/ui/tokens/led_state.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

import '../../helpers/ui_test_helpers.dart';

Widget _eyes(Widget eyes) => regiHost(
  eyes,
  brightness: Brightness.dark,
  background: const Color(0xFF0A0C0D),
);

EyePose _pose(
  LedState state,
  EyeGroup group,
  double seconds, {
  int index = 0,
  bool animate = true,
}) => eyePose(
  state: state,
  group: group,
  index: index,
  seconds: seconds,
  animate: animate,
);

void main() {
  group('eyePose (el lenguaje de los ojos)', () {
    test('en línea: fuera y centro encendidos con halo que respira', () {
      for (final group in [EyeGroup.outer, EyeGroup.center]) {
        expect(_pose(LedState.online, group, 0).lit, 1);
        expect(_pose(LedState.online, group, 0).glow, closeTo(1.2, .001));
        // A mitad del ciclo (3,2 s) el halo está en su punto más grande.
        expect(_pose(LedState.online, group, 1.6).glow, closeTo(4, .001));
      }
    });

    test('en línea: los del medio guiñan dos veces por ciclo', () {
      double lit(double s) => _pose(LedState.online, EyeGroup.middle, s).lit;

      expect(lit(0), 0, reason: 'apagados casi todo el ciclo');
      expect(lit(.72 * 4.2), 1, reason: 'primer guiño');
      expect(lit(.82 * 4.2), 0, reason: 'entre guiños');
      expect(lit(.90 * 4.2), 1, reason: 'segundo guiño');
      expect(lit(1.5 * 4.2), 0, reason: 'el ciclo se repite');
    });

    test('sin conexión: todos apagados y un latido tenue en el borde', () {
      for (final group in EyeGroup.values) {
        expect(_pose(LedState.offline, group, 0).lit, 0);
        expect(_pose(LedState.offline, group, 0).rimAlpha, closeTo(.2, .001));
        expect(_pose(LedState.offline, group, 2).lit, 0);
        expect(_pose(LedState.offline, group, 2).rimAlpha, closeTo(.65, .001));
      }
    });

    test('servicio caído: rojo en tres tiempos', () {
      double lit(EyeGroup group, double s) =>
          _pose(LedState.down, group, s).lit;

      // Tiempo 1 (0,24 s): fuera y centro.
      expect(lit(EyeGroup.outer, .24), 1);
      expect(lit(EyeGroup.center, .24), 1);
      expect(lit(EyeGroup.middle, .24), 0);
      // Tiempo 2 (1,0 s): fuera y medios; el centro ya se apagó.
      expect(lit(EyeGroup.outer, 1.0), 1);
      expect(lit(EyeGroup.middle, 1.0), 1);
      expect(lit(EyeGroup.center, 1.0), 0);
      // Tiempo 3 (1,92 s): solo los medios.
      expect(lit(EyeGroup.outer, 1.92), 0);
      expect(lit(EyeGroup.middle, 1.92), 1);
      expect(lit(EyeGroup.center, 1.92), 0);
      // Entre un tiempo y otro la transición es gradual.
      expect(lit(EyeGroup.outer, 1.56), closeTo(.5, .001));
    });

    test('sincronizando: fuera y medios se turnan y el centro queda fijo', () {
      expect(_pose(LedState.sync, EyeGroup.outer, 0).lit, 1);
      expect(_pose(LedState.sync, EyeGroup.middle, 0).lit, 0);
      expect(_pose(LedState.sync, EyeGroup.outer, .8).lit, 0);
      expect(_pose(LedState.sync, EyeGroup.middle, .8).lit, closeTo(1, .001));
      for (final s in [0.0, .3, .8, 1.3, 5.0]) {
        expect(_pose(LedState.sync, EyeGroup.center, s).lit, 1);
      }
    });

    test('movimiento reducido: pose fija, sin depender del tiempo', () {
      const expected = {
        LedState.online: [1.0, 0.0, 1.0],
        LedState.offline: [0.0, 0.0, 0.0],
        LedState.down: [1.0, 1.0, 0.0],
        LedState.sync: [1.0, 1.0, 1.0],
      };
      for (final MapEntry(key: state, value: lit) in expected.entries) {
        for (final (i, group) in EyeGroup.values.indexed) {
          for (final seconds in [0.0, .7, 3.1]) {
            expect(
              _pose(state, group, seconds, animate: false).lit,
              lit[i],
              reason: '$state/$group',
            );
          }
        }
      }
    });
  });

  group('LedEyes', () {
    testWidgets('dibuja los seis Regis en los cuatro estados sin errores', (
      tester,
    ) async {
      for (final variant in RegiVariant.values) {
        for (final state in LedState.values) {
          await tester.pumpWidget(
            _eyes(LedEyes(state: state, variant: variant)),
          );
          await tester.pump(const Duration(milliseconds: 700));
          expect(
            tester.takeException(),
            isNull,
            reason: '${variant.name}/${state.name}',
          );
        }
      }
    });

    testWidgets('los ojos se animan', (tester) async {
      await tester.pumpWidget(_eyes(const LedEyes(state: LedState.online)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets('con «reducir movimiento» quedan quietos', (tester) async {
      reduceMotion(tester);

      await tester.pumpWidget(_eyes(const LedEyes(state: LedState.sync)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('activar «reducir movimiento» detiene los ojos en marcha', (
      tester,
    ) async {
      await tester.pumpWidget(_eyes(const LedEyes(state: LedState.down)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      reduceMotion(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
