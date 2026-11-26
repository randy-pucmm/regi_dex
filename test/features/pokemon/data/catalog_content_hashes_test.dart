import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/features/pokemon/data/catalog_local_source.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_mapper.dart';

import '../../../core/database/database_test_helpers.dart';
import 'catalog_test_data.dart';

void main() {
  late AppDatabase db;
  late CatalogLocalSource local;

  setUp(() async {
    db = createTestDatabase();
    local = CatalogLocalSource(db);
    await local.saveReference(mapReferenceData(syntheticReference()));
    await local.savePokemon(
      mapPokemonPage({
        'pokemon': [for (var id = 1; id <= 5; id++) syntheticPokemon(id)],
      }, DateTime(2026, 11, 26)),
    );
  });
  tearDown(() => db.close());

  test(
    'con datos intactos el hash guardado y el recalculado coinciden',
    () async {
      final hashes = await local.contentHashes();

      expect(hashes.keys, [1, 2, 3, 4, 5]);
      expect(hashes.values.every((h) => h.stored == h.computed), isTrue);
    },
  );

  test('coincide con el cálculo por id', () async {
    final hashes = await local.contentHashes();

    expect(hashes[3]!.computed, await local.localContentHash(3));
  });

  test('un nombre editado en la base cambia el hash recalculado', () async {
    await (db.update(db.pokemons)..where((p) => p.id.equals(2))).write(
      const PokemonsCompanion(name: Value('hackeado')),
    );

    final hashes = await local.contentHashes();

    expect(hashes[2]!.stored, isNot(hashes[2]!.computed));
    expect(hashes[1]!.stored, hashes[1]!.computed);
  });

  test('un stat o un tipo alterados también se detectan', () async {
    await (db.update(db.pokemonStats)
          ..where((s) => s.pokemonId.equals(3) & s.statId.equals(1)))
        .write(const PokemonStatsCompanion(baseStat: Value(255)));
    await (db.delete(
      db.pokemonTypes,
    )..where((t) => t.pokemonId.equals(4))).go();

    final hashes = await local.contentHashes();

    expect(hashes[3]!.stored, isNot(hashes[3]!.computed));
    expect(hashes[4]!.stored, isNot(hashes[4]!.computed));
  });

  test('con ids solo devuelve esos', () async {
    final hashes = await local.contentHashes(ids: [2, 5]);

    expect(hashes.keys, [2, 5]);
  });
}
