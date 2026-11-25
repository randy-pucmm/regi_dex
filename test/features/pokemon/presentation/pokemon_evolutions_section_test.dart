import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/image_providers.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/features/pokemon/domain/evolution_chain.dart';
import 'package:regi_dex/features/pokemon/presentation/pokemon_evolutions_section.dart';

import '../../../helpers/fake_image_cache.dart';
import '../../../helpers/ui_test_helpers.dart';

EvolutionNode _node(
  int id,
  String name, {
  List<EvolutionStep> steps = const [],
  List<EvolutionNode> children = const [],
}) => EvolutionNode(
  species: EvolutionSpecies(id: id, name: name),
  steps: steps,
  children: children,
);

Future<void> _open(WidgetTester tester, EvolutionChain? chain) async {
  useScreen(tester, const Size(390, 700));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pokemonEvolutionsProvider(1).overrideWith((ref) => Stream.value(chain)),
        imageCacheManagerProvider.overrideWithValue(FakeImageCache()),
      ],
      child: regiHost(const PokemonEvolutionsSection(pokemonId: 1)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra cada etapa con su condición', (tester) async {
    await _open(
      tester,
      EvolutionChain(
        currentSpeciesId: 2,
        roots: [
          _node(
            1,
            'bulbasaur',
            children: [
              _node(
                2,
                'ivysaur',
                steps: const [EvolutionStep(minLevel: 16)],
                children: [
                  _node(
                    3,
                    'venusaur',
                    steps: const [EvolutionStep(minLevel: 32)],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    expect(find.text('Bulbasaur'), findsOneWidget);
    expect(find.text('Ivysaur'), findsOneWidget);
    expect(find.text('Nv. 16'), findsOneWidget);
    expect(find.text('Venusaur'), findsOneWidget);
    expect(find.text('Nv. 32'), findsOneWidget);
  });

  testWidgets('una cadena de una sola especie dice «No evoluciona»', (
    tester,
  ) async {
    await _open(
      tester,
      EvolutionChain(currentSpeciesId: 1, roots: [_node(1, 'ditto')]),
    );

    expect(find.text('No evoluciona.'), findsOneWidget);
  });

  testWidgets('sin datos avisa que se descargan con conexión', (tester) async {
    await _open(tester, null);

    expect(find.textContaining('se descargan con conexión'), findsOneWidget);
  });
}
