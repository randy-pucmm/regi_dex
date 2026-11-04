import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';

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
