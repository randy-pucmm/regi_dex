import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_detail_repository_impl.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_move.dart';

import '../../../core/database/database_test_helpers.dart';
import 'fake_pokemon_remote.dart';

Map<String, dynamic> _response({String effectEs = 'Sube el ataque.'}) => {
  'pokemon': [
    {
      'id': 1,
      'pokemonspecy': {
        'id': 1,
        'pokemonspeciesnames': [
          {
            'name': 'Bulbasaur',
            'genus': 'Pokémon Semilla',
            'language': {'name': 'es'},
          },
        ],
      },
      'pokemonmoves': [
        {
          'move_id': 1,
          'level': 5,
          'move_learn_method_id': 1,
          'version_group_id': 20,
        },
        {
          'move_id': 2,
          'level': null,
          'move_learn_method_id': 4,
          'version_group_id': 20,
        },
      ],
      'pokemonabilities': [
        {
          'ability': {
            'id': 65,
            'abilitynames': [
              {
                'name': 'Espesura',
                'language': {'name': 'es'},
              },
            ],
            'abilityeffecttexts': [
              {
                'short_effect': 'Boosts attack.',
                'language': {'name': 'en'},
              },
              {
                'short_effect': effectEs,
                'language': {'name': 'es'},
              },
            ],
          },
        },
      ],
    },
  ],
};

void main() {
  late AppDatabase db;
  late FakePokemonRemote remote;
  late PokemonDetailRepositoryImpl repository;

  setUp(() async {
    db = createTestDatabase();
    remote = FakePokemonRemote();
    repository = PokemonDetailRepositoryImpl(
      catalog: db.catalogDao,
      remote: remote,
    );
    addTearDown(db.close);
    await seedReference(db);
    await seedMoves(db);
    await upsertBulbasaur(db);
  });

  Future<void> saveBulbasaurMoves() => db.catalogDao.saveDetail(
    pokemonId: 1,
    speciesId: 1,
    syncedAt: DateTime(2026, 11, 20),
    abilities: const [],
    moves: bulbasaurMoves(),
  );

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

  test('un id fuera del catálogo emite null', () async {
    expect(await repository.watchDetail(999).first, isNull);
  });

  test('refreshDetail guarda nombre y efecto en español', () async {
    remote.details[1] = _response();

    await repository.refreshDetail(1);

    final ability = (await repository.watchDetail(1).first)!.abilities.first;
    expect(ability.nameEs, 'Espesura');
    expect(ability.shortEffect, 'Sube el ataque.');
    expect((await db.catalogDao.getPokemon(1))!.detailSyncedAt, isNotNull);
  });

  test('un detalle reciente no se vuelve a pedir', () async {
    remote.details[1] = _response();

    await repository.refreshDetail(1);
    await repository.refreshDetail(1);

    expect(remote.detailCalls, [1]);
  });

  test('un detalle reciente pero sin movimientos se vuelve a pedir', () async {
    await db.catalogDao.saveDetail(
      pokemonId: 1,
      speciesId: 1,
      syncedAt: DateTime.now(),
      abilities: const [],
      moves: const [],
    );
    remote.details[1] = _response();

    await repository.refreshDetail(1);

    expect(remote.detailCalls, [1]);
    expect(await db.catalogDao.hasMoves(1), isTrue);
  });

  test('un detalle de hace más de una semana se vuelve a pedir', () async {
    remote.details[1] = _response();
    await repository.refreshDetail(1);

    await withClock(
      Clock.fixed(DateTime.now().add(const Duration(days: 8))),
      () => repository.refreshDetail(1),
    );

    expect(remote.detailCalls, [1, 1]);
  });

  test('sin red falla y conserva lo local', () async {
    await expectLater(
      repository.refreshDetail(1),
      throwsA(isA<NetworkFailure>()),
    );

    final detail = (await repository.watchDetail(1).first)!;
    expect(detail.abilities.first.shortEffect, isNull);
    expect((await db.catalogDao.getPokemon(1))!.detailSyncedAt, isNull);
  });

  test('una respuesta sin el Pokémon es un ValidationFailure', () async {
    remote.details[1] = {'pokemon': <dynamic>[]};

    await expectLater(
      repository.refreshDetail(1),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('refreshDetail guarda los movimientos que aprende', () async {
    remote.details[1] = _response();

    await repository.refreshDetail(1);

    final levelUp = await repository.moves(1, MoveMethod.levelUp, page: 0);
    expect([for (final m in levelUp.moves) (m.name, m.level)], [('move-1', 5)]);
    final machine = await repository.moves(1, MoveMethod.machine, page: 0);
    expect([for (final m in machine.moves) m.name], ['move-2']);
  });

  test('entrega 10 movimientos por página, en orden de nivel', () async {
    await saveBulbasaurMoves();

    final first = await repository.moves(1, MoveMethod.levelUp, page: 0);
    expect(
      [for (final m in first.moves) m.level],
      [for (var i = 1; i <= 10; i++) i],
    );
    expect((first.page, first.totalPages), (0, 3));
    expect((first.hasPrevious, first.hasNext), (false, true));

    final last = await repository.moves(1, MoveMethod.levelUp, page: 2);
    expect(
      [for (final m in last.moves) m.level],
      [for (var i = 21; i <= 30; i++) i],
    );
    expect((last.hasPrevious, last.hasNext), (true, false));
  });

  test('«Todos» junta los métodos sin repetir movimientos', () async {
    await saveBulbasaurMoves();

    final pages = [
      for (var page = 0; page < 4; page++)
        await repository.moves(1, MoveMethod.all, page: page),
    ];

    final names = [for (final p in pages) ...p.moves.map((m) => m.name)];
    expect(names, hasLength(32));
    expect(names.toSet(), hasLength(32));
    expect(pages.first.totalPages, 4);
    expect(pages[3].moves, hasLength(2));
  });

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

    final ivysaur = await repository.moves(2, MoveMethod.levelUp, page: 0);

    expect(ivysaur.moves, isEmpty);
  });

  test('cada método usa el juego más reciente donde existe', () async {
    await db.catalogDao.saveDetail(
      pokemonId: 1,
      speciesId: 1,
      syncedAt: DateTime(2026, 11, 20),
      abilities: const [],
      moves: const [
        (moveId: 1, versionGroupId: 20, methodId: 1, level: 5),
        (moveId: 2, versionGroupId: 10, methodId: 4, level: 0),
        (moveId: 3, versionGroupId: 15, methodId: 4, level: 0),
        (moveId: 4, versionGroupId: 12, methodId: 3, level: 0),
        (moveId: 5, versionGroupId: 30, methodId: 12, level: 0),
      ],
    );

    Future<List<String>> names(MoveMethod method) async => [
      for (final m in (await repository.moves(1, method, page: 0)).moves)
        m.name,
    ];

    expect(await names(MoveMethod.levelUp), ['move-1']);
    expect(await names(MoveMethod.machine), ['move-3']);
    expect(await names(MoveMethod.tutor), ['move-4']);
    expect(await names(MoveMethod.all), hasLength(5));
  });

  test('una última página incompleta trae lo que queda', () async {
    await saveBulbasaurMoves();

    final machine = await repository.moves(1, MoveMethod.machine, page: 0);

    expect(machine.moves, hasLength(5));
    expect(machine.totalPages, 1);
  });

  test('solo usa el grupo de versiones más reciente', () async {
    await saveBulbasaurMoves();

    final names = <String>[
      for (var page = 0; page < 3; page++)
        ...(await repository.moves(
          1,
          MoveMethod.levelUp,
          page: page,
        )).moves.map((m) => m.name),
    ];

    expect(names, hasLength(30));
    expect(names, isNot(contains('move-31')));
  });

  test('trae tipo, datos y clase de daño del movimiento', () async {
    await saveBulbasaurMoves();

    final move = (await repository.moves(
      1,
      MoveMethod.levelUp,
      page: 0,
    )).moves.first;

    expect(
      (move.name, move.typeName, move.power, move.accuracy, move.pp),
      ('move-1', 'poison', 41, 100, 25),
    );
    expect(move.category, MoveCategory.physical);
  });

  test('sin movimientos guardados la página viene vacía', () async {
    final page = await repository.moves(1, MoveMethod.egg, page: 0);

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
}
