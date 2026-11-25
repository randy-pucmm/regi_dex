import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_detail_repository_impl.dart';
import 'package:regi_dex/features/pokemon/domain/evolution_chain.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_move.dart';

import '../../../core/database/database_test_helpers.dart';

void main() {
  late AppDatabase db;
  late PokemonDetailRepositoryImpl repository;

  setUp(() async {
    db = createTestDatabase();
    repository = PokemonDetailRepositoryImpl(
      catalog: db.catalogDao,
      reference: db.referenceDao,
    );
    addTearDown(db.close);
    await seedReference(db);
    await seedMoves(db);
    await upsertBulbasaur(db);
  });

  Future<void> saveMoves(
    List<({int moveId, int versionGroupId, int methodId, int level})> moves,
  ) => db.catalogDao.replacePokemonMoves(1, [
    for (final m in moves)
      PokemonMovesCompanion.insert(
        pokemonId: 1,
        moveId: m.moveId,
        versionGroupId: m.versionGroupId,
        learnMethodId: m.methodId,
        level: Value(m.level),
      ),
  ]);

  Future<void> saveBulbasaurMoves() => saveMoves(bulbasaurMoves());

  test('entrega tipos, stats y habilidades del Pokémon guardado', () async {
    final detail = (await repository.watchDetail(1).first)!;

    expect(detail.pokemon.name, 'Bulbasaur');
    expect([for (final t in detail.pokemon.types) t.name], ['grass', 'poison']);
    expect(detail.stats, {1: 45, 2: 49, 3: 49});
    expect(
      [for (final a in detail.abilities) a.name],
      ['overgrow', 'chlorophyll'],
    );
    expect([for (final a in detail.abilities) a.isHidden], [false, true]);
  });

  test('la eficacia de tipos sale de la referencia local', () async {
    await db.referenceDao.upsertReferenceData(
      typeEfficacies: [
        TypeEfficaciesCompanion.insert(
          attackingTypeId: 4,
          defendingTypeId: 12,
          factor: 200,
        ),
      ],
    );

    final chart = await repository.watchTypeChart().first;

    expect([for (final t in chart.types) t.name], ['poison', 'grass']);
    expect(chart.multiplier(4, [12]), 2);
  });

  test('un id fuera del catálogo emite null', () async {
    expect(await repository.watchDetail(999).first, isNull);
  });

  Future<MovePage> moves(
    MoveMethod method, {
    int game = 20,
    int page = 0,
    int pokemon = 1,
  }) => repository.moves(pokemon, method, versionGroupId: game, page: page);

  Future<List<String>> names(MoveMethod method, {required int game}) async => [
    for (final m in (await moves(method, game: game)).moves) m.name,
  ];

  test('entrega 10 movimientos por página, en orden de nivel', () async {
    await saveBulbasaurMoves();

    final first = await moves(MoveMethod.levelUp);
    expect(
      [for (final m in first.moves) m.level],
      [for (var i = 1; i <= 10; i++) i],
    );
    expect((first.page, first.totalPages), (0, 3));
    expect((first.hasPrevious, first.hasNext), (false, true));

    final last = await moves(MoveMethod.levelUp, page: 2);
    expect(
      [for (final m in last.moves) m.level],
      [for (var i = 21; i <= 30; i++) i],
    );
    expect((last.hasPrevious, last.hasNext), (true, false));
  });

  test(
    '«Todos» junta los métodos de un juego sin repetir movimientos',
    () async {
      await saveBulbasaurMoves();

      final pages = [
        for (var page = 0; page < 3; page++)
          await moves(MoveMethod.all, page: page),
      ];

      final all = [for (final p in pages) ...p.moves.map((m) => m.name)];
      expect(all, hasLength(30));
      expect(all.toSet(), hasLength(30));
      expect(pages.first.totalPages, 3);
    },
  );

  test('«Nivel» solo trae lo que aprende ese Pokémon', () async {
    await saveBulbasaurMoves();
    await db.catalogDao.upsertSpecies(
      SpeciesCompanion.insert(
        id: const Value(2),
        name: 'ivysaur',
        generationId: 1,
      ),
    );
    await db.catalogDao.upsertPokemon(
      PokemonsCompanion.insert(
        id: const Value(2),
        speciesId: 2,
        name: 'Ivysaur',
        lightSyncedAt: DateTime(2026, 11, 3),
      ),
      types: const [],
      stats: const [],
      abilities: const [],
    );

    expect((await moves(MoveMethod.levelUp, pokemon: 2)).moves, isEmpty);
  });

  group('juegos', () {
    Future<void> saveVenusaurLike() => saveMoves(const [
      (moveId: 1, versionGroupId: 20, methodId: 1, level: 5),
      (moveId: 2, versionGroupId: 10, methodId: 4, level: 0),
      (moveId: 3, versionGroupId: 15, methodId: 4, level: 0),
      (moveId: 4, versionGroupId: 15, methodId: 3, level: 0),
      (moveId: 5, versionGroupId: 30, methodId: 12, level: 0),
    ]);

    test('lista los juegos del más reciente al más antiguo', () async {
      await saveVenusaurLike();

      final games = await repository.moveGames(1);

      expect([for (final g in games.games) g.id], [30, 20, 15, 10]);
    });

    test(
      'al abrir usa el juego más reciente con movimientos por nivel',
      () async {
        await saveVenusaurLike();

        expect((await repository.moveGames(1)).defaultId, 20);
      },
    );

    test('sin movimientos por nivel usa el juego más reciente', () async {
      await saveMoves(const [
        (moveId: 2, versionGroupId: 10, methodId: 4, level: 0),
        (moveId: 3, versionGroupId: 15, methodId: 4, level: 0),
      ]);

      expect((await repository.moveGames(1)).defaultId, 15);
    });

    test('cada juego trae solo sus movimientos', () async {
      await saveVenusaurLike();

      expect(await names(MoveMethod.machine, game: 10), ['move-2']);
      expect(await names(MoveMethod.machine, game: 15), ['move-3']);
      expect(await names(MoveMethod.tutor, game: 15), ['move-4']);
      expect(await names(MoveMethod.machine, game: 20), isEmpty);
      expect(await names(MoveMethod.levelUp, game: 20), ['move-1']);
    });

    test('«Todos» de un juego incluye todos sus métodos', () async {
      await saveVenusaurLike();

      expect(await names(MoveMethod.all, game: 15), ['move-3', 'move-4']);
      expect(await names(MoveMethod.all, game: 30), ['move-5']);
    });

    test('el nombre del juego sale de la referencia', () async {
      await saveVenusaurLike();
      await db.referenceDao.upsertReferenceData(
        versionGroups: [
          VersionGroupsCompanion.insert(
            id: const Value(20),
            name: 'sword-shield',
          ),
        ],
      );

      final games = (await repository.moveGames(1)).games;

      expect(games.firstWhere((g) => g.id == 20).label, 'Sword Shield');
      expect(games.firstWhere((g) => g.id == 10).label, 'Group 10');
    });

    test('sin movimientos guardados no hay juegos', () async {
      final games = await repository.moveGames(1);

      expect(games.games, isEmpty);
      expect(games.defaultId, isNull);
    });
  });

  test('una última página incompleta trae lo que queda', () async {
    await saveBulbasaurMoves();

    final machine = await moves(MoveMethod.machine);

    expect(machine.moves, hasLength(5));
    expect(machine.totalPages, 1);
  });

  test('trae tipo, datos y clase de daño del movimiento', () async {
    await saveBulbasaurMoves();

    final move = (await moves(MoveMethod.levelUp)).moves.first;

    expect(
      (move.name, move.typeName, move.power, move.accuracy, move.pp),
      ('move-1', 'poison', 41, 100, 25),
    );
    expect(move.category, MoveCategory.physical);
  });

  test('un juego sin movimientos de ese método da una página vacía', () async {
    await saveBulbasaurMoves();

    final page = await moves(MoveMethod.egg);

    expect(page.moves, isEmpty);
    expect(page.totalPages, 0);
    expect(page.hasNext, isFalse);
  });

  test('la clase de daño se traduce desde el id de PokéAPI', () {
    expect(
      [
        for (final id in [1, 2, 3, 9, null]) MoveCategory.fromId(id),
      ],
      [
        MoveCategory.status,
        MoveCategory.physical,
        MoveCategory.special,
        null,
        null,
      ],
    );
  });

  group('evoluciones', () {
    EvolutionsCompanion step(
      int to,
      String name, {
      int? from,
      String? trigger,
      int? level,
      int? happiness,
      String? time,
      String? item,
    }) => EvolutionsCompanion.insert(
      chainId: 1,
      toSpeciesId: to,
      toSpeciesName: name,
      fromSpeciesId: Value(from),
      trigger: Value(trigger),
      minLevel: Value(level),
      minHappiness: Value(happiness),
      timeOfDay: Value(time),
      item: Value(item),
    );

    Future<void> saveChain(List<EvolutionsCompanion> steps) async {
      await db.catalogDao.upsertSpecies(
        SpeciesCompanion.insert(
          id: const Value(1),
          name: 'bulbasaur',
          generationId: 1,
          evolutionChainId: const Value(1),
        ),
      );
      await db.catalogDao.replaceEvolutionChain(1, steps);
    }

    Future<EvolutionChain> chain() async =>
        (await repository.watchEvolutions(1).first)!;

    List<(String, int, String)> flat(EvolutionChain chain) => [
      for (final (node, depth) in chain.flattened)
        (node.species.name, depth, node.requirement),
    ];

    test('una línea de tres etapas sale como árbol con sus niveles', () async {
      await saveChain([
        step(1, 'bulbasaur'),
        step(2, 'ivysaur', from: 1, trigger: 'level-up', level: 16, time: ''),
        step(3, 'venusaur', from: 2, trigger: 'level-up', level: 32),
      ]);

      final result = await chain();

      expect(flat(result), [
        ('bulbasaur', 0, ''),
        ('ivysaur', 1, 'Nv. 16'),
        ('venusaur', 2, 'Nv. 32'),
      ]);
      expect(result.currentSpeciesId, 1);
      expect(result.evolves, isTrue);
    });

    test('una cadena con ramas lista cada una con su condición', () async {
      await saveChain([
        step(1, 'eevee'),
        step(2, 'flareon', from: 1, trigger: 'use-item', item: 'fire-stone'),
        step(
          3,
          'espeon',
          from: 1,
          trigger: 'level-up',
          happiness: 220,
          time: 'day',
        ),
      ]);

      expect(flat(await chain()), [
        ('eevee', 0, ''),
        ('flareon', 1, 'Usar fire stone'),
        ('espeon', 1, 'Felicidad 220 · de día'),
      ]);
    });

    test('una evolución con dos condiciones las junta con «o»', () async {
      await saveChain([
        step(1, 'a'),
        step(2, 'b', from: 1, trigger: 'level-up', level: 30),
        step(2, 'b', from: 1, trigger: 'trade'),
      ]);

      expect(flat(await chain()).last, ('b', 1, 'Nv. 30 o Intercambio'));
    });

    test('las condiciones repetidas se muestran una sola vez', () async {
      await saveChain([
        step(1, 'eevee'),
        step(2, 'leafeon', from: 1, trigger: 'level-up'),
        step(2, 'leafeon', from: 1, trigger: 'level-up'),
        step(2, 'leafeon', from: 1, trigger: 'use-item', item: 'leaf-stone'),
      ]);

      expect(flat(await chain()).last, (
        'leafeon',
        1,
        'Subir de nivel o Usar leaf stone',
      ));
    });

    test('una especie sin evoluciones no evoluciona', () async {
      await saveChain([step(1, 'ditto')]);

      expect((await chain()).evolves, isFalse);
    });

    test('sin descargar la cadena emite null', () async {
      await db.catalogDao.upsertSpecies(
        SpeciesCompanion.insert(
          id: const Value(1),
          name: 'bulbasaur',
          generationId: 1,
          evolutionChainId: const Value(1),
        ),
      );

      expect(await repository.watchEvolutions(1).first, isNull);
    });
  });

  group('EvolutionStep', () {
    test('describe cada condición en español', () {
      expect(const EvolutionStep(trigger: 'trade').label, 'Intercambio');
      expect(const EvolutionStep(trigger: 'level-up').label, 'Subir de nivel');
      expect(
        const EvolutionStep(minLevel: 20, timeOfDay: 'night').label,
        'Nv. 20 · de noche',
      );
      expect(const EvolutionStep(trigger: 'shed').label, '');
    });
  });
}
