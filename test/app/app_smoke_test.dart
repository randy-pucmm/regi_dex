import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/app.dart';
import 'package:regi_dex/app/providers.dart';

import '../core/connectivity/connectivity_fakes.dart';
import '../core/database/database_test_helpers.dart';
import '../features/pokemon/fake_pokemon_repository.dart';

/// Abre la app sin red real ni disco: BD en memoria y repositorio falso, para
/// que la sincronización automática no salga a PokéAPI.
Future<void> _pumpApp(WidgetTester tester) async {
  final db = createTestDatabase();
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        networkSourceProvider.overrideWithValue(FakeNetworkSource()),
        healthCheckerProvider.overrideWithValue(FakeHealthChecker()),
        appDatabaseProvider.overrideWithValue(db),
        pokemonRepositoryProvider.overrideWithValue(FakePokemonRepository()),
      ],
      child: const RegiDexApp(),
    ),
  );
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
