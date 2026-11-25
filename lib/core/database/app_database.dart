import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/api_call_log_dao.dart';
import 'daos/catalog_dao.dart';
import 'daos/favorite_dao.dart';
import 'daos/preference_dao.dart';
import 'daos/reference_dao.dart';
import 'daos/sync_metadata_dao.dart';
import 'tables/catalog_tables.dart';
import 'tables/reference_tables.dart';
import 'tables/sync_tables.dart';
import 'tables/user_tables.dart';

part 'app_database.g.dart';

/// Base de datos local (SQLite con Drift): fuente de verdad que observa la UI.
/// Generar el código con `dart run build_runner build --delete-conflicting-outputs`.
@DriftDatabase(
  tables: [
    Generations,
    Types,
    EggGroups,
    Abilities,
    Moves,
    VersionGroups,
    TypeEfficacies,
    Species,
    SpeciesEggGroups,
    Pokemons,
    PokemonTypes,
    PokemonStats,
    PokemonAbilities,
    PokemonMoves,
    SpeciesEvolutions,
    Favorites,
    UserPreferences,
    SyncMetadataEntries,
    ApiCallLogs,
  ],
  daos: [
    CatalogDao,
    ReferenceDao,
    FavoriteDao,
    PreferenceDao,
    SyncMetadataDao,
    ApiCallLogDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Abre `regidex.sqlite` en el directorio de documentos de la app.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'regidex'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Drift no expresa COLLATE en @TableIndex: búsqueda por nombre sin distinguir mayúsculas.
      await customStatement(
        'CREATE INDEX idx_pokemon_name_nocase ON pokemon (name COLLATE NOCASE)',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(pokemonMoves);
      if (from < 3) await m.createTable(speciesEvolutions);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
