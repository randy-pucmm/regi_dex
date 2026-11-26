import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/image_providers.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_detail.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_move.dart';
import 'package:regi_dex/features/pokemon/domain/type_chart.dart';
import 'package:regi_dex/features/pokemon/presentation/pokemon_detail_page.dart';
import 'package:regi_dex/ui/themes/regi_themes.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

import '../../../core/database/database_test_helpers.dart';
import '../../../helpers/fake_image_cache.dart';
import '../../../helpers/ui_test_helpers.dart';

PokemonDetail _detail({
  Map<int, int> stats = const {},
  List<PokemonFormRef> forms = const [],
}) => PokemonDetail(
  pokemon: const Pokemon(
    id: 1,
    name: 'bulbasaur',
    baseStatTotal: 318,
    types: [PokemonTypeRef(id: 12, name: 'grass', nameEs: 'planta')],
  ),
  height: 7,
  weight: 69,
  shinyUrl: 'https://example.test/shiny.png',
  eggGroups: const ['monstruo', 'planta'],
  forms: forms,
  stats: stats,
  abilities: const [
    PokemonAbilityRef(name: 'overgrow', isHidden: false, shortEffect: 'Sube.'),
    PokemonAbilityRef(name: 'chlorophyll', isHidden: true),
  ],
);

Future<void> _open(
  WidgetTester tester,
  Stream<PokemonDetail?> detail, {
  List<String>? shared,
}) async {
  useScreen(tester, const Size(390, 844));
  final db = createTestDatabase();
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pokemonDetailProvider(1).overrideWith((ref) => detail),
        pokemonDetailRefreshProvider(1).overrideWith((ref) => true),
        pokemonEvolutionsProvider(1).overrideWith((ref) => Stream.value(null)),
        typeChartProvider.overrideWith(
          (ref) => Stream.value(const TypeChart.empty()),
        ),
        pokemonMoveGamesProvider(1)
            .overrideWith((ref) => const MoveGames.empty()),
        pokemonDetailProvider(2).overrideWith((ref) => Stream.value(null)),
        pokemonDetailRefreshProvider(2).overrideWith((ref) => false),
        appDatabaseProvider.overrideWithValue(db),
        favoriteIdsProvider.overrideWith((ref) => Stream.value({1})),
        shareTextProvider.overrideWithValue((text) async => shared?.add(text)),
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

  testWidgets('muestra altura, peso y grupos huevo', (tester) async {
    await _open(tester, Stream.value(_detail()));

    expect(find.text('0,7 m'), findsOneWidget);
    expect(find.text('6,9 kg'), findsOneWidget);
    expect(find.text('Monstruo, Planta'), findsOneWidget);
  });

  testWidgets('alterna shiny y refleja el favorito', (tester) async {
    await _open(tester, Stream.value(_detail()));
    await tester.pump();

    expect(find.byTooltip('Quitar de favoritos'), findsOneWidget);
    await tester.tap(find.byTooltip('Ver shiny'));
    await tester.pump();

    expect(find.byTooltip('Ver color normal'), findsOneWidget);
  });

  testWidgets('compartir envía nombre, número y tipos', (tester) async {
    final shared = <String>[];
    await _open(tester, Stream.value(_detail()), shared: shared);

    await tester.tap(find.byTooltip('Compartir'));

    expect(shared, ['Bulbasaur (N.º 0001) · Tipo: Planta · RegiDex']);
  });

  testWidgets('una forma sin descargar conserva la base y avisa', (
    tester,
  ) async {
    await _open(
      tester,
      Stream.value(
        _detail(
          forms: const [
            PokemonFormRef(id: 1, label: 'Normal'),
            PokemonFormRef(id: 2, label: 'Mega'),
          ],
        ),
      ),
    );

    await tester.ensureVisible(find.text('Mega'));
    await tester.tap(find.text('Mega'));
    await tester.pumpAndSettle();

    expect(find.textContaining('forma se descarga'), findsOneWidget);
    expect(find.text('Monstruo, Planta'), findsOneWidget);
  });

  testWidgets('cada región muestra solo sus formas', (tester) async {
    await _open(
      tester,
      Stream.value(
        _detail(
          forms: const [
            PokemonFormRef(id: 1, label: 'Normal'),
            PokemonFormRef(id: 2, label: 'Alola'),
            PokemonFormRef(id: 3, label: 'Mega'),
          ],
        ),
      ),
    );

    expect(find.text('Alola'), findsNothing);
    await tester.ensureVisible(find.text('Normal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Normal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alola'));
    await tester.pumpAndSettle();

    expect(find.textContaining('forma se descarga'), findsOneWidget);
    expect(find.text('Mega'), findsNothing);

    await tester.tap(find.text('Alola'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Normal'));
    await tester.pumpAndSettle();

    expect(find.text('Mega'), findsOneWidget);
  });

  testWidgets('los disfraces de Pikachu van en su propio selector', (
    tester,
  ) async {
    await _open(
      tester,
      Stream.value(
        _detail(
          forms: const [
            PokemonFormRef(id: 1, label: 'Normal'),
            PokemonFormRef(id: 2, label: 'Alola Cap'),
            PokemonFormRef(id: 3, label: 'Rock Star'),
            PokemonFormRef(id: 4, label: 'Gmax'),
          ],
        ),
      ),
    );

    expect(find.text('Gmax'), findsOneWidget);
    expect(find.text('Rock Star'), findsNothing);
    await tester.ensureVisible(find.text('Disfraces'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disfraces'));
    await tester.pumpAndSettle();

    expect(find.text('Alola Cap'), findsOneWidget);
    expect(find.text('Rock Star'), findsOneWidget);
  });

  test('el efecto largo se recorta a 160 caracteres como máximo', () {
    final ability = PokemonAbilityRef(
      name: 'x',
      isHidden: false,
      shortEffect: 'palabra ' * 40,
    );

    expect(ability.summary!.length, lessThanOrEqualTo(160));
    expect(ability.summary, endsWith('palabra…'));
  });

  testWidgets('un Pokémon que no está en el catálogo lo dice', (tester) async {
    await _open(tester, Stream.value(null));

    expect(find.textContaining('no está en el catálogo'), findsOneWidget);
  });
}
