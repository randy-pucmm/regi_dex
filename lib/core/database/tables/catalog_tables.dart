import 'package:drift/drift.dart';

import 'reference_tables.dart';

// Catálogo sincronizado desde PokéAPI (D09). Las FK no tienen cascada: las
// relaciones de un Pokémon se reemplazan explícitamente (PS-06).

@DataClassName('SpeciesRow')
@TableIndex(name: 'idx_species_generation_id', columns: {#generationId})
class Species extends Table {
  @override
  String get tableName => 'species';

  IntColumn get id => integer()();
  TextColumn get name => text()();
  IntColumn get generationId => integer().references(Generations, #id)();
  IntColumn get evolutionChainId => integer().nullable()();
  BoolColumn get isLegendary => boolean().withDefault(const Constant(false))();
  BoolColumn get isMythical => boolean().withDefault(const Constant(false))();
  TextColumn get nameEs => text().nullable()();
  TextColumn get genusEs => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SpeciesEggGroupRow')
@TableIndex(name: 'idx_species_egg_group_egg_group_id', columns: {#eggGroupId})
class SpeciesEggGroups extends Table {
  @override
  String get tableName => 'species_egg_group';

  IntColumn get speciesId => integer().references(Species, #id)();
  IntColumn get eggGroupId => integer().references(EggGroups, #id)();

  @override
  Set<Column> get primaryKey => {speciesId, eggGroupId};
}

/// Pokémon del catálogo. `contentHash` (OF-19) y `detailSyncedAt` se llenan
/// cuando llegan el hash de integridad y el detalle.
@DataClassName('PokemonRow')
@TableIndex(name: 'idx_pokemon_species_id', columns: {#speciesId})
@TableIndex(name: 'idx_pokemon_base_stat_total', columns: {#baseStatTotal})
class Pokemons extends Table {
  @override
  String get tableName => 'pokemon';

  IntColumn get id => integer()();
  IntColumn get speciesId => integer().references(Species, #id)();
  TextColumn get name => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(true))();
  IntColumn get height => integer().withDefault(const Constant(0))();
  IntColumn get weight => integer().withDefault(const Constant(0))();
  IntColumn get baseStatTotal => integer().withDefault(const Constant(0))();
  TextColumn get spriteUrl => text().nullable()();
  TextColumn get artworkUrl => text().nullable()();
  TextColumn get contentHash => text().nullable()();
  DateTimeColumn get lightSyncedAt => dateTime()();
  DateTimeColumn get detailSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PokemonTypeRow')
@TableIndex(name: 'idx_pokemon_type_type_id', columns: {#typeId})
class PokemonTypes extends Table {
  @override
  String get tableName => 'pokemon_type';

  IntColumn get pokemonId => integer().references(Pokemons, #id)();
  IntColumn get slot => integer()();
  IntColumn get typeId => integer().references(Types, #id)();

  @override
  Set<Column> get primaryKey => {pokemonId, slot};
}

@DataClassName('PokemonStatRow')
class PokemonStats extends Table {
  @override
  String get tableName => 'pokemon_stat';

  IntColumn get pokemonId => integer().references(Pokemons, #id)();
  IntColumn get statId => integer()();
  IntColumn get baseStat => integer()();

  @override
  Set<Column> get primaryKey => {pokemonId, statId};
}

@DataClassName('PokemonAbilityRow')
@TableIndex(name: 'idx_pokemon_ability_ability_id', columns: {#abilityId})
class PokemonAbilities extends Table {
  @override
  String get tableName => 'pokemon_ability';

  IntColumn get pokemonId => integer().references(Pokemons, #id)();
  IntColumn get slot => integer()();
  IntColumn get abilityId => integer().references(Abilities, #id)();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {pokemonId, slot};
}
