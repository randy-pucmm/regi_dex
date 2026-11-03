import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';

import 'database_test_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<List<String>> sqliteMaster(String type) async {
    final rows = await db
        .customSelect(
          'SELECT name FROM sqlite_master WHERE type = ?',
          variables: [Variable<String>(type)],
        )
        .get();
    return [for (final row in rows) row.read<String>('name')];
  }

  test('schemaVersion es 1', () {
    expect(db.schemaVersion, 1);
  });

  test('crea las tablas con los nombres del documento', () async {
    expect(
      await sqliteMaster('table'),
      containsAll([
        'generation',
        'type',
        'egg_group',
        'ability',
        'move',
        'version_group',
        'type_efficacy',
        'species',
        'species_egg_group',
        'pokemon',
        'pokemon_type',
        'pokemon_stat',
        'pokemon_ability',
        'favorite',
        'user_preference',
        'sync_metadata',
        'api_call_log',
      ]),
    );
  });

  test('crea los índices documentados', () async {
    expect(
      await sqliteMaster('index'),
      containsAll([
        'idx_pokemon_name_nocase',
        'idx_pokemon_base_stat_total',
        'idx_pokemon_species_id',
        'idx_species_generation_id',
        'idx_pokemon_type_type_id',
        'idx_pokemon_ability_ability_id',
        'idx_species_egg_group_egg_group_id',
        'idx_api_call_log_called_at',
      ]),
    );
  });

  test(
    'la búsqueda por nombre sin distinguir mayúsculas usa su índice',
    () async {
      final plan = await db
          .customSelect(
            "EXPLAIN QUERY PLAN SELECT id FROM pokemon WHERE name = 'bulbasaur' COLLATE NOCASE",
          )
          .get();
      final details = plan.map((row) => row.read<String>('detail')).join(' ');
      expect(details, contains('idx_pokemon_name_nocase'));
    },
  );

  test('las foreign keys están activas', () async {
    await expectLater(
      db.catalogDao.upsertSpecies(
        SpeciesCompanion.insert(
          id: const Value(1),
          name: 'bulbasaur',
          generationId: 99,
        ),
      ),
      throwsA(anything),
    );
  });

  test('ninguna FK tiene cascada', () async {
    final tables = [
      'species',
      'species_egg_group',
      'pokemon',
      'pokemon_type',
      'pokemon_stat',
      'pokemon_ability',
    ];
    for (final table in tables) {
      final fks = await db
          .customSelect("PRAGMA foreign_key_list('$table')")
          .get();
      expect(fks, isNotEmpty, reason: table);
      for (final fk in fks) {
        expect(fk.read<String>('on_delete'), 'NO ACTION', reason: table);
        expect(fk.read<String>('on_update'), 'NO ACTION', reason: table);
      }
    }
  });

  test('las tablas de usuario y de sync no referencian el catálogo', () async {
    for (final table in [
      'favorite',
      'user_preference',
      'sync_metadata',
      'api_call_log',
    ]) {
      final fks = await db
          .customSelect("PRAGMA foreign_key_list('$table')")
          .get();
      expect(fks, isEmpty, reason: table);
    }
  });
}
