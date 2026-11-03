import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/app.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: RegiDexApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('abre en Inicio con los cinco destinos', (tester) async {
    await _pumpApp(tester);

    for (final label in [
      'Catálogo',
      'Favoritos',
      'Equipos',
      'Trivia',
      'Ajustes',
    ]) {
      expect(find.widgetWithText(FilledButton, label), findsOneWidget);
    }
    expect(find.text('Inicio'), findsNothing);
  });

  testWidgets('cada destino se abre y «Inicio» regresa al hub', (tester) async {
    await _pumpApp(tester);

    for (final label in [
      'Catálogo',
      'Favoritos',
      'Equipos',
      'Trivia',
      'Ajustes',
    ]) {
      await tester.tap(find.widgetWithText(FilledButton, label));
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Inicio'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, label), findsOneWidget);
    }
  });
}
