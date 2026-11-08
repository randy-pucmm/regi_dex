import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/components/indicator_glyph.dart';

import '../../helpers/ui_test_helpers.dart';

Widget _mark(IndicatorGlyph glyph) =>
    regiHost(IndicatorMark(glyph: glyph, color: Colors.green));

void main() {
  testWidgets('solo el anillo de sincronización se mueve', (tester) async {
    for (final glyph in IndicatorGlyph.values) {
      await tester.pumpWidget(_mark(glyph));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        tester.binding.transientCallbackCount > 0,
        glyph == IndicatorGlyph.syncing,
        reason: glyph.name,
      );
    }
  });

  testWidgets('con «reducir movimiento» el anillo queda quieto', (
    tester,
  ) async {
    reduceMotion(tester);

    await tester.pumpWidget(_mark(IndicatorGlyph.syncing));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('al dejar de sincronizar el anillo se detiene', (tester) async {
    await tester.pumpWidget(_mark(IndicatorGlyph.syncing));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pumpWidget(_mark(IndicatorGlyph.solid));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.binding.transientCallbackCount, 0);
  });
}
