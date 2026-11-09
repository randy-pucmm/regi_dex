import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/components/shell_status_band.dart';
import 'package:regi_dex/ui/tokens/regi_colors.dart';

import '../../helpers/ui_test_helpers.dart';

Widget _band({required bool progress, double width = 360}) => regiHost(
  SizedBox(
    width: width,
    child: ShellStatusBand(
      color: RegiLedColors.sync,
      title: 'Sincronizando',
      subtitle: 'En línea · puedes seguir navegando',
      progress: progress,
      leading: const SizedBox.square(dimension: 46),
      trailing: const SizedBox.square(dimension: 46),
    ),
  ),
  brightness: Brightness.dark,
);

Finder get _bar =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SyncBar');

void main() {
  testWidgets('la barra fina solo aparece al sincronizar', (tester) async {
    await tester.pumpWidget(_band(progress: false));
    final heightWithout = tester.getSize(find.byType(ShellStatusBand)).height;
    expect(_bar, findsNothing);

    await tester.pumpWidget(_band(progress: true));

    expect(_bar, findsOneWidget);
    expect(
      tester.getSize(find.byType(ShellStatusBand)).height,
      greaterThan(heightWithout),
    );
  });

  testWidgets('la barra se mueve, y con «reducir movimiento» queda quieta', (
    tester,
  ) async {
    await tester.pumpWidget(_band(progress: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    reduceMotion(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('no desborda en una banda estrecha con el texto al 200 %', (
    tester,
  ) async {
    useScreen(tester, const Size(800, 600), textScale: 2);
    await tester.pumpWidget(_band(progress: true, width: 300));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });
}
