import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon.dart';
import 'package:regi_dex/features/pokemon/domain/type_chart.dart';
import 'package:regi_dex/features/pokemon/presentation/pokemon_matchups_section.dart';

import '../../../helpers/ui_test_helpers.dart';

const _fire = PokemonTypeRef(id: 1, name: 'fire', nameEs: 'fuego');
const _grass = PokemonTypeRef(id: 2, name: 'grass', nameEs: 'planta');
const _ice = PokemonTypeRef(id: 3, name: 'ice', nameEs: 'hielo');

Future<void> _open(WidgetTester tester, TypeChart chart) async {
  useScreen(tester, const Size(390, 600));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [typeChartProvider.overrideWith((ref) => Stream.value(chart))],
      child: regiHost(const PokemonMatchupsSection(types: [_grass])),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('agrupa los tipos por multiplicador', (tester) async {
    await _open(
      tester,
      const TypeChart(
        types: [_fire, _grass, _ice],
        percents: {(1, 2): 200, (3, 2): 200, (2, 2): 50},
      ),
    );

    expect(find.text('×2'), findsOneWidget);
    expect(find.text('FUEGO'), findsOneWidget);
    expect(find.text('HIELO'), findsOneWidget);
    expect(find.text('×½'), findsOneWidget);
    expect(find.text('PLANTA'), findsOneWidget);
    expect(find.text('×4'), findsNothing);
  });

  testWidgets('sin datos de referencia avisa que se calculan al descargar', (
    tester,
  ) async {
    await _open(tester, const TypeChart.empty());

    expect(find.textContaining('al descargar el catálogo'), findsOneWidget);
  });
}
