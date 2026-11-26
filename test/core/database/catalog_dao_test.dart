import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/database/daos/catalog_dao.dart';

import 'database_test_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await seedReference(db);
  });
  tearDown(() => db.close());

  test(
    'tres sincronizaciones seguidas no cambian el conteo por tabla (PA-13)',
    () async {
      await upsertBulbasaur(db);
      final first = await catalogCounts(db);

      await upsertBulbasaur(db);
      await seedReference(db);
      await upsertBulbasaur(db);

      expect(await catalogCounts(db), first);
      expect(first['pokemon'], 1);
      expect(first['pokemon_type'], 2);
      expect(first['pokemon_stat'], 3);
      expect(first['pokemon_ability'], 2);
      expect(first['species_egg_group'], 2);
    },
  );

  test('las formas no cuentan ni salen en el catálogo', () async {
    await upsertBulbasaur(db);
    await db.catalogDao.upsertPokemon(
      PokemonsCompanion.insert(
        id: const Value(10033),
        speciesId: 1,
        name: 'venusaur-mega',
        isDefault: const Value(false),
        lightSyncedAt: DateTime(2026, 11, 3),
      ),
      types: const [],
      stats: const [],
      abilities: const [],
    );

    final listed = await db.catalogDao.watchPokemonWithTypes().first;

    expect([for (final p in listed) p.pokemon.id], [1]);
    expect(await db.catalogDao.countPokemon(), 1);
  });

  test('upsertPokemon actualiza la fila existente', () async {
    await upsertBulbasaur(db);
    await db.catalogDao.upsertPokemon(
      PokemonsCompanion.insert(
        id: const Value(1),
        speciesId: 1,
        name: 'Bulbasaur',
        baseStatTotal: const Value(320),
        lightSyncedAt: DateTime(2026, 11, 4, 9),
      ),
      types: const [(slot: 1, typeId: 12)],
      stats: const [],
      abilities: const [],
    );

    final pokemon = await db.catalogDao.getPokemon(1);
    expect(pokemon!.baseStatTotal, 320);
    expect(pokemon.lightSyncedAt, DateTime(2026, 11, 4, 9));
    expect(await db.catalogDao.countPokemon(), 1);
  });

  test('reemplaza las relaciones en lugar de acumularlas (PS-06)', () async {
    await upsertBulbasaur(db);
    expect(await rowCount(db, 'pokemon_type'), 2);

    await upsertBulbasaur(db, types: const [(slot: 1, typeId: 12)]);

    expect(await rowCount(db, 'pokemon_type'), 1);
    expect(await rowCount(db, 'pokemon_stat'), 3);
    expect(await rowCount(db, 'pokemon_ability'), 2);
  });

  test('replaceSpeciesEggGroups reemplaza los grupos huevo', () async {
    await upsertBulbasaur(db);
    await db.catalogDao.replaceSpeciesEggGroups(1, [7]);

    final rows = await db.select(db.speciesEggGroups).get();
    expect([for (final row in rows) row.eggGroupId], [7]);
  });

  test('getPokemon devuelve null si no existe', () async {
    expect(await db.catalogDao.getPokemon(404), isNull);
  });

  group('watchPokemonWithTypes', () {
    Future<void> addPokemon(
      int id, {
      List<({int slot, int typeId})> types = const [],
    }) async {
      await db.catalogDao.upsertSpecies(
        SpeciesCompanion.insert(
          id: Value(id),
          name: 'species-$id',
          generationId: 1,
        ),
      );
      await db.catalogDao.upsertPokemon(
        PokemonsCompanion.insert(
          id: Value(id),
          speciesId: id,
          name: 'pokemon-$id',
          lightSyncedAt: DateTime(2026, 11, 7),
        ),
        types: types,
        stats: const [],
        abilities: const [],
      );
    }

    /// Resumen `id: [tipos]` de cada Pokémon emitido.
    Future<Map<int, List<String>>> summary() async => {
      for (final item in await db.catalogDao.watchPokemonWithTypes().first)
        item.pokemon.id: [for (final type in item.types) type.name],
    };

    test('une los tipos por slot aunque se hayan guardado al revés', () async {
      await addPokemon(
        1,
        types: const [(slot: 2, typeId: 4), (slot: 1, typeId: 12)],
      );

      expect(await summary(), {
        1: ['grass', 'poison'],
      });
    });

    test('un Pokémon sin tipos aparece con la lista vacía', () async {
      await addPokemon(7);

      expect(await summary(), {7: <String>[]});
    });

    test('ordena por id', () async {
      await addPokemon(25, types: const [(slot: 1, typeId: 12)]);
      await addPokemon(1, types: const [(slot: 1, typeId: 4)]);
      await addPokemon(4);

      expect((await summary()).keys, [1, 4, 25]);
    });

    test('emite una vez por transacción y no por fila', () async {
      final emissions = <List<int>>[];
      final subscription = db.catalogDao.watchPokemonWithTypes().listen(
        (items) => emissions.add([for (final i in items) i.pokemon.id]),
      );
      await pumpEventQueue();

      await db.transaction(() async {
        await addPokemon(1, types: const [(slot: 1, typeId: 12)]);
        await addPokemon(2, types: const [(slot: 1, typeId: 4)]);
      });
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions, [
        <int>[],
        [1, 2],
      ]);
    });

    test('refleja el reemplazo de tipos', () async {
      await upsertBulbasaur(db);
      final names = db.catalogDao.watchPokemonWithTypes().map(
        (items) => [for (final type in items.single.types) type.name],
      );
      final expectation = expectLater(
        names,
        emitsInOrder([
          ['grass', 'poison'],
          ['grass'],
        ]),
      );
      await pumpEventQueue();

      await upsertBulbasaur(db, types: const [(slot: 1, typeId: 12)]);
      await expectation;
    });
  });

  group('watchPokemonWithTypes con criterios', () {
    Future<List<int>> idsFor(CatalogCriteria criteria) async => [
      for (final item
          in await db.catalogDao.watchPokemonWithTypes(criteria).first)
        item.pokemon.id,
    ];

    setUp(() => seedSearchCatalog(db));

    test('sin criterios devuelve todo por número', () async {
      expect(await idsFor(const CatalogCriteria()), [25, 26, 233, 377, 378]);
    });

    test('por número nacional exacto', () async {
      expect(await idsFor(const CatalogCriteria(number: 377)), [377]);
      expect(await idsFor(const CatalogCriteria(number: 378)), [378]);
      expect(await idsFor(const CatalogCriteria(number: 3)), isEmpty);
    });

    test('por trozo del nombre, sin distinguir mayúsculas', () async {
      expect(await idsFor(const CatalogCriteria(namePart: 'pika')), [25]);
      expect(await idsFor(const CatalogCriteria(namePart: 'chu')), [25, 26]);
      expect(await idsFor(const CatalogCriteria(namePart: 'reg')), [377, 378]);
    });

    test('el nombre guardado con mayúsculas también se encuentra', () async {
      await upsertBulbasaur(db);

      expect(await idsFor(const CatalogCriteria(namePart: 'bulba')), [1]);
    });

    test('% y _ se buscan tal cual, no como comodines', () async {
      expect(await idsFor(const CatalogCriteria(namePart: '%')), isEmpty);
      expect(await idsFor(const CatalogCriteria(namePart: '_')), isEmpty);
    });

    test('número y nombre juntos deben cumplirse a la vez', () async {
      expect(
        await idsFor(const CatalogCriteria(number: 25, namePart: 'pika')),
        [25],
      );
      expect(
        await idsFor(const CatalogCriteria(number: 26, namePart: 'pika')),
        isEmpty,
      );
    });

    test('mantiene los tipos de los resultados', () async {
      await upsertSimplePokemon(db, 400, 'pikablue', typeId: 4);

      final items = await db.catalogDao
          .watchPokemonWithTypes(const CatalogCriteria(namePart: 'pika'))
          .first;

      expect(items.map((i) => i.types.map((t) => t.id).toList()), [
        [12],
        [4],
      ]);
    });

    test('emite de nuevo al llegar un Pokémon que coincide', () async {
      final stream = db.catalogDao.watchPokemonWithTypes(
        const CatalogCriteria(namePart: 'zap'),
      );
      final emissions = expectLater(
        stream.map((items) => items.map((i) => i.pokemon.id).toList()),
        emitsInOrder([
          isEmpty,
          [145],
        ]),
      );

      await upsertSimplePokemon(db, 145, 'zapdos');
      await emissions;
    });
  });

  test('watchAllPokemon y watchPokemonCount emiten al escribir', () async {
    final ids = db.catalogDao.watchAllPokemon().map(
      (rows) => [for (final row in rows) row.id],
    );
    final counts = db.catalogDao.watchPokemonCount();

    final idsExpectation = expectLater(
      ids,
      emitsInOrder([
        emits(isEmpty),
        emitsThrough([1]),
      ]),
    );
    await pumpEventQueue();
    final countsExpectation = expectLater(counts, emitsThrough(1));
    await pumpEventQueue();

    await upsertBulbasaur(db);
    await idsExpectation;
    await countsExpectation;
  });

  test('borrar un Pokémon no toca los favoritos', () async {
    await upsertBulbasaur(db);
    await db.favoriteDao.addFavorite(1);
    await db.favoriteDao.addFavorite(999); // sin fila en el catálogo

    await db.catalogDao.upsertPokemon(
      PokemonsCompanion.insert(
        id: const Value(1),
        speciesId: 1,
        name: 'Bulbasaur',
        lightSyncedAt: DateTime(2026, 11, 3, 10),
      ),
      types: const [],
      stats: const [],
      abilities: const [],
    );
    await db.delete(db.pokemons).go();

    expect(await db.catalogDao.countPokemon(), 0);
    expect(await db.favoriteDao.watchFavoriteIds().first, {1, 999});
  });
}
