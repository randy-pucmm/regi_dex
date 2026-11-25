import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/image_providers.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_detail.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_move.dart';
import 'package:regi_dex/features/pokemon/presentation/pokemon_detail_page.dart';
import 'package:regi_dex/ui/themes/regi_themes.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

import '../../../helpers/fake_image_cache.dart';
import '../../../helpers/ui_test_helpers.dart';

PokemonDetail _detail({Map<int, int> stats = const {}}) => PokemonDetail(
  pokemon: const Pokemon(
    id: 1,
    name: 'bulbasaur',
    baseStatTotal: 318,
    types: [PokemonTypeRef(id: 12, name: 'grass', nameEs: 'planta')],
  ),
  height: 7,
  weight: 69,
  stats: stats,
  abilities: const [
    PokemonAbilityRef(name: 'overgrow', isHidden: false, shortEffect: 'Sube.'),
    PokemonAbilityRef(name: 'chlorophyll', isHidden: true),
  ],
);

Future<void> _open(WidgetTester tester, Stream<PokemonDetail?> detail) async {
  useScreen(tester, const Size(390, 844));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pokemonDetailProvider(1).overrideWith((ref) => detail),
        pokemonDetailRefreshProvider(1).overrideWith((ref) => true),
        pokemonMovesProvider.overrideWith(
          (ref, request) => const MovePage(moves: [], page: 0, totalPages: 0),
        ),
        imageCacheManagerProvider.overrideWithValue(FakeImageCache()),
      ],
      child: MaterialApp(
        theme: RegiThemes.build(RegiVariant.regirock, Brightness.light),
        home: const Scaffold(body: PokemonDetailPage(id: 1)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('muestra identidad, tipos y marca la habilidad oculta', (
    tester,
  ) async {
    await _open(tester, Stream.value(_detail(stats: {1: 45})));

    expect(find.text('Bulbasaur'), findsOneWidget);
    expect(find.text('N.º 0001'), findsOneWidget);
    expect(find.text('PLANTA'), findsOneWidget);
    expect(find.text('Chlorophyll · Oculta'), findsOneWidget);
    expect(find.text('Sube.'), findsOneWidget);
  });

  testWidgets('sin stats guardados avisa que se descargan con conexión', (
    tester,
  ) async {
    await _open(tester, Stream.value(_detail()));

    expect(find.textContaining('estadísticas se descargan'), findsOneWidget);
  });

  testWidgets('un Pokémon que no está en el catálogo lo dice', (tester) async {
    await _open(tester, Stream.value(null));

    expect(find.textContaining('no está en el catálogo'), findsOneWidget);
  });
}
