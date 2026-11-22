import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/components/hex_choice.dart';
import 'package:regi_dex/ui/components/regi_filter_chip.dart';
import 'package:regi_dex/ui/components/type_chip.dart';
import 'package:regi_dex/ui/tokens/regi_colors.dart';

import '../../helpers/ui_test_helpers.dart';

Widget _onPanel(Widget child) => ColoredBox(
  color: RegiInk.panel,
  child: Center(child: child),
);

void main() {
  group('RegiFilterChip', () {
    testWidgets('muestra el texto y avisa al tocarlo', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        regiHost(
          _onPanel(
            RegiFilterChip(
              label: 'Gen. I',
              selected: false,
              onTap: () => taps++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Gen. I'));

      expect(taps, 1);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('la elegida lleva «✓», no solo color', (tester) async {
      await tester.pumpWidget(
        regiHost(
          _onPanel(
            RegiFilterChip(label: 'Gen. I', selected: true, onTap: () {}),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('mide al menos 48 dp de alto', (tester) async {
      await tester.pumpWidget(
        regiHost(
          _onPanel(RegiFilterChip(label: 'X', selected: false, onTap: () {})),
        ),
      );

      expect(
        tester.getSize(find.byType(RegiFilterChip)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('se anuncia como botón elegido o no', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        regiHost(
          _onPanel(
            RegiFilterChip(label: 'Gen. I', selected: true, onTap: () {}),
          ),
        ),
      );

      final data = tester.getSemantics(find.byType(RegiFilterChip));
      expect(data.label, 'Gen. I');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isSelected, Tristate.isTrue);
      handle.dispose();
    });
  });

  group('TypeChip como opción de filtro', () {
    testWidgets('sin selected no cambia: etiqueta sin «✓»', (tester) async {
      await tester.pumpWidget(
        regiHost(_onPanel(const TypeChip(typeKey: 'rock', label: 'Roca'))),
      );

      expect(find.text('ROCA'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('elegido lleva «✓» y no elegido no', (tester) async {
      await tester.pumpWidget(
        regiHost(
          _onPanel(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TypeChip(
                  key: const ValueKey('on'),
                  typeKey: 'rock',
                  label: 'Roca',
                  selected: true,
                  onTap: () {},
                ),
                TypeChip(
                  key: const ValueKey('off'),
                  typeKey: 'fire',
                  label: 'Fuego',
                  selected: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('on')),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('off')),
          matching: find.byIcon(Icons.check),
        ),
        findsNothing,
      );
    });

    testWidgets('elegido o no mide lo mismo, así no salta la lista', (
      tester,
    ) async {
      Future<Size> sizeOf(bool selected) async {
        await tester.pumpWidget(
          regiHost(
            _onPanel(
              TypeChip(
                typeKey: 'rock',
                label: 'Roca',
                selected: selected,
                onTap: () {},
              ),
            ),
          ),
        );
        return tester.getSize(find.byType(TypeChip));
      }

      final off = await sizeOf(false);
      final on = await sizeOf(true);

      expect(on.height, off.height);
    });

    testWidgets('avisa al tocarlo', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        regiHost(
          _onPanel(
            TypeChip(
              typeKey: 'rock',
              label: 'Roca',
              selected: false,
              onTap: () => taps++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('ROCA'));

      expect(taps, 1);
    });
  });

  group('HexChoice de selección múltiple', () {
    testWidgets('con multiple no se anuncia como grupo excluyente', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        regiHost(
          _onPanel(
            HexChoice(
              label: 'A',
              selected: true,
              multiple: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      final data = tester.getSemantics(find.byType(HexChoice));
      expect(data.flagsCollection.isInMutuallyExclusiveGroup, isFalse);
      handle.dispose();
    });

    testWidgets('sin multiple sigue siendo excluyente', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        regiHost(
          _onPanel(HexChoice(label: 'A', selected: true, onPressed: () {})),
        ),
      );

      final data = tester.getSemantics(find.byType(HexChoice));
      expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      handle.dispose();
    });
  });
}
