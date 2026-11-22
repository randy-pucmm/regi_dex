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
    'pokemon_move',
    'evolution',
    'pokemon_form',
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

/// Inserta la especie y el Pokémon [id] con [name] y un tipo (requiere
/// [seedReference]). Sirve para armar catálogos pequeños en las pruebas.
Future<void> upsertSimplePokemon(
  AppDatabase db,
  int id,
  String name, {
  int typeId = 12,
}) async {
  await db.catalogDao.upsertSpecies(
    SpeciesCompanion.insert(id: Value(id), name: name, generationId: 1),
  );
  await db.catalogDao.upsertPokemon(
    PokemonsCompanion.insert(
      id: Value(id),
      speciesId: id,
      name: name,
      lightSyncedAt: DateTime(2026, 11, 3, 10),
    ),
    types: [(slot: 1, typeId: typeId)],
    stats: const [],
    abilities: const [],
  );
}

/// Catálogo de búsqueda: Pikachu, Raichu, Porygon2, Regirock y Regice.
Future<void> seedSearchCatalog(AppDatabase db) async {
  await upsertSimplePokemon(db, 25, 'pikachu');
  await upsertSimplePokemon(db, 26, 'raichu');
  await upsertSimplePokemon(db, 233, 'porygon2');
  await upsertSimplePokemon(db, 377, 'regirock');
  await upsertSimplePokemon(db, 378, 'regice');
}

/// Referencia para los catálogos de filtros: generaciones 1 a 3, tipos, grupos
/// huevo y habilidades con los ids que usa [seedFilterCatalog].
Future<void> seedFilterReference(AppDatabase db) {
  return db.referenceDao.upsertReferenceData(
    generations: [
      for (final (id, name, region) in const [
        (1, 'generation-i', 'kanto'),
        (2, 'generation-ii', 'johto'),
        (3, 'generation-iii', 'hoenn'),
      ])
        GenerationsCompanion.insert(
          id: Value(id),
          name: name,
          region: Value(region),
        ),
    ],
    types: [
      for (final (id, name) in const [
        (3, 'flying'),
        (5, 'ground'),
        (6, 'rock'),
        (10, 'fire'),
        (12, 'grass'),
        (13, 'electric'),
        (15, 'ice'),
      ])
        TypesCompanion.insert(id: Value(id), name: name),
    ],
    eggGroups: [
      for (final (id, name) in const [
        (1, 'monster'),
        (2, 'dragon'),
        (3, 'mineral'),
        (4, 'field'),
        (5, 'undiscovered'),
      ])
        EggGroupsCompanion.insert(id: Value(id), name: name),
    ],
    abilities: [
      for (final (id, name) in const [
        (5, 'sturdy'),
        (9, 'static'),
        (29, 'clear-body'),
        (66, 'blaze'),
        (69, 'rock-head'),
      ])
        AbilitiesCompanion.insert(id: Value(id), name: name),
    ],
  );
}

/// Inserta un Pokémon completo (especie, grupos huevo, tipos y habilidades)
/// para probar filtros y orden; requiere [seedFilterReference].
Future<void> upsertFilterPokemon(
  AppDatabase db,
  int id,
  String name, {
  required int generation,
  required List<int> types,
  required List<int> eggGroups,
  required List<int> abilities,
  required int total,
}) async {
  await db.catalogDao.upsertSpecies(
    SpeciesCompanion.insert(
      id: Value(id),
      name: name.toLowerCase(),
      generationId: generation,
    ),
  );
  await db.catalogDao.replaceSpeciesEggGroups(id, eggGroups);
  await db.catalogDao.upsertPokemon(
    PokemonsCompanion.insert(
      id: Value(id),
      speciesId: id,
      name: name,
      baseStatTotal: Value(total),
      lightSyncedAt: DateTime(2026, 11, 3, 10),
    ),
    types: [
      for (final (index, typeId) in types.indexed)
        (slot: index + 1, typeId: typeId),
    ],
    stats: const [],
    abilities: [
      for (final (index, abilityId) in abilities.indexed)
        (slot: index + 1, abilityId: abilityId, isHidden: false),
    ],
  );
}

/// Siete Pokémon de tres generaciones para probar filtros y orden:
/// Charizard, Pikachu, Geodude y Golem (gen. 1), Chikorita (gen. 2), y Regirock
/// y Regice (gen. 3). Geodude, Golem y Regirock son de roca.
Future<void> seedFilterCatalog(AppDatabase db) async {
  await seedFilterReference(db);
  Future<void> add(
    int id,
    String name,
    int generation,
    List<int> types,
    List<int> eggGroups,
    List<int> abilities,
    int total,
  ) => upsertFilterPokemon(
    db,
    id,
    name,
    generation: generation,
    types: types,
    eggGroups: eggGroups,
    abilities: abilities,
    total: total,
  );
  await add(6, 'charizard', 1, [10, 3], [1, 2], [66], 534);
  await add(25, 'pikachu', 1, [13], [4], [9], 320);
  await add(74, 'geodude', 1, [6, 5], [3], [69, 5], 300);
  await add(76, 'golem', 1, [6, 5], [3], [69, 5], 495);
  await add(152, 'chikorita', 2, [12], [1], [66], 318);
  await add(377, 'regirock', 3, [6], [5], [5], 580);
  await add(378, 'regice', 3, [15], [5], [29], 580);
}
