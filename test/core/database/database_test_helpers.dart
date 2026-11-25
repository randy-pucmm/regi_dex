import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:regi_dex/core/database/app_database.dart';

/// Base de datos en memoria con el esquema real, para pruebas.
AppDatabase createTestDatabase() => AppDatabase(NativeDatabase.memory());

/// Cantidad de filas de [table] (nombre SQL).
Future<int> rowCount(AppDatabase db, String table) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS c FROM $table')
      .getSingle();
  return row.read<int>('c');
}

/// Conteo de filas de todas las tablas de catálogo, referencia y relación.
Future<Map<String, int>> catalogCounts(AppDatabase db) async => {
  for (final table in const [
    'generation',
    'type',
    'egg_group',
    'ability',
    'species',
    'species_egg_group',
    'pokemon',
    'pokemon_type',
    'pokemon_stat',
    'pokemon_ability',
  ])
    table: await rowCount(db, table),
};

/// Inserta los datos de referencia mínimos que necesitan las pruebas del catálogo.
Future<void> seedReference(AppDatabase db) {
  return db.referenceDao.upsertReferenceData(
    generations: [
      GenerationsCompanion.insert(
        id: const Value(1),
        name: 'generation-i',
        region: const Value('kanto'),
      ),
    ],
    types: [
      TypesCompanion.insert(id: const Value(12), name: 'grass'),
      TypesCompanion.insert(id: const Value(4), name: 'poison'),
    ],
    eggGroups: [
      EggGroupsCompanion.insert(id: const Value(1), name: 'monster'),
      EggGroupsCompanion.insert(id: const Value(7), name: 'plant'),
    ],
    abilities: [
      AbilitiesCompanion.insert(id: const Value(65), name: 'overgrow'),
      AbilitiesCompanion.insert(id: const Value(34), name: 'chlorophyll'),
    ],
  );
}

/// Inserta la especie 1 y el Pokémon 1 (Bulbasaur) con sus relaciones.
/// [types] permite probar el reemplazo de relaciones.
Future<void> upsertBulbasaur(
  AppDatabase db, {
  List<({int slot, int typeId})> types = const [
    (slot: 1, typeId: 12),
    (slot: 2, typeId: 4),
  ],
}) async {
  await db.catalogDao.upsertSpecies(
    SpeciesCompanion.insert(
      id: const Value(1),
      name: 'bulbasaur',
      generationId: 1,
    ),
  );
  await db.catalogDao.replaceSpeciesEggGroups(1, [1, 7]);
  await db.catalogDao.upsertPokemon(
    PokemonsCompanion.insert(
      id: const Value(1),
      speciesId: 1,
      name: 'Bulbasaur',
      baseStatTotal: const Value(318),
      lightSyncedAt: DateTime(2026, 11, 3, 10),
    ),
    types: types,
    stats: const [
      (statId: 1, baseStat: 45),
      (statId: 2, baseStat: 49),
      (statId: 3, baseStat: 49),
    ],
    abilities: const [
      (slot: 1, abilityId: 65, isHidden: false),
      (slot: 3, abilityId: 34, isHidden: true),
    ],
  );
}

/// 32 movimientos de referencia (`move-1`…`move-32`), de tipo planta o veneno.
Future<void> seedMoves(AppDatabase db) => db.referenceDao.upsertReferenceData(
  moves: [
    for (var id = 1; id <= 32; id++)
      MovesCompanion.insert(
        id: Value(id),
        name: 'move-$id',
        typeId: Value(id.isEven ? 12 : 4),
        power: Value(40 + id),
        accuracy: const Value(100),
        pp: const Value(25),
        damageClassId: Value(id % 3 + 1),
      ),
  ],
);

/// Lo que aprende Bulbasaur: `move-1`…`move-30` por nivel y `move-1`…`move-5`
/// por MT en el grupo 20, y `move-31` y `move-32` por nivel solo en el grupo 10
/// (más antiguo).
List<({int moveId, int versionGroupId, int methodId, int level})>
bulbasaurMoves() => [
  for (var id = 1; id <= 30; id++)
    (moveId: id, versionGroupId: 20, methodId: 1, level: id),
  for (var id = 1; id <= 5; id++)
    (moveId: id, versionGroupId: 20, methodId: 4, level: 0),
  (moveId: 31, versionGroupId: 10, methodId: 1, level: 1),
  (moveId: 32, versionGroupId: 10, methodId: 1, level: 2),
];
