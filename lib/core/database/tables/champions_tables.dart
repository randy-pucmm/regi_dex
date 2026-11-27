import 'package:drift/drift.dart';

// Caché de Champions Battle Data (D12, ADR-008). Sin FK hacia el catálogo:
// `pokeapi_*_id` es solo la correspondencia con PokéAPI y puede ser nula.

/// Versión del índice descargado. Una sola fila, con clave `index`.
@DataClassName('ChampionsMetaRow')
class ChampionsMeta extends Table {
  @override
  String get tableName => 'champions_meta';

  TextColumn get key => text()();
  TextColumn get dataVersion => text()();
  DateTimeColumn get generatedAt => dateTime()();
  TextColumn get defaultSeason => text()();

  /// Última vez que se confirmó el índice contra el servicio (vigencia de 24 h).
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Pokémon del índice. Las estadísticas son las de nivel 50 con 0 SP y
/// naturaleza neutra. `types` va separado por comas y `abilities` por `|`.
@DataClassName('ChampionsPokemonRow')
class ChampionsPokemons extends Table {
  @override
  String get tableName => 'champions_pokemon';

  TextColumn get showdownId => text()();
  TextColumn get name => text()();
  TextColumn get showdownName => text()();
  TextColumn get types => text()();
  TextColumn get abilities => text()();
  TextColumn get hiddenAbility => text().nullable()();
  IntColumn get hp => integer()();
  IntColumn get attack => integer()();
  IntColumn get defense => integer()();
  IntColumn get spAttack => integer()();
  IntColumn get spDefense => integer()();
  IntColumn get speed => integer()();
  TextColumn get spriteUrl => text()();
  IntColumn get pokeapiPokemonId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {showdownId};
}

/// Movimiento que un Pokémon puede aprender en Champions.
@DataClassName('ChampionsLearnableMoveRow')
class ChampionsLearnableMoves extends Table {
  @override
  String get tableName => 'champions_learnable_move';

  TextColumn get showdownId => text()();
  TextColumn get moveName => text()();
  IntColumn get pokeapiMoveId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {showdownId, moveName};
}

/// Estadísticas de uso por Pokémon, formato, temporada y categoría. Para la
/// categoría `stat_points` el reparto va en las columnas `sp_*`.
@DataClassName('ChampionsUsageRow')
class ChampionsUsages extends Table {
  @override
  String get tableName => 'champions_usage';

  TextColumn get showdownId => text()();
  TextColumn get format => text()();
  TextColumn get season => text()();
  TextColumn get category => text()();
  IntColumn get rank => integer()();
  TextColumn get name => text().withDefault(const Constant(''))();
  RealColumn get percentage => real().nullable()();
  TextColumn get statUp => text().nullable()();
  TextColumn get statDown => text().nullable()();
  IntColumn get spHp => integer().nullable()();
  IntColumn get spAttack => integer().nullable()();
  IntColumn get spDefense => integer().nullable()();
  IntColumn get spSpAttack => integer().nullable()();
  IntColumn get spSpDefense => integer().nullable()();
  IntColumn get spSpeed => integer().nullable()();

  @override
  Set<Column> get primaryKey => {showdownId, format, season, category, rank};
}
