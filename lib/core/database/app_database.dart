import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/api_call_log_dao.dart';
import 'daos/catalog_dao.dart';
import 'daos/champions_dao.dart';
import 'daos/favorite_dao.dart';
import 'daos/preference_dao.dart';
import 'daos/reference_dao.dart';
import 'daos/sync_metadata_dao.dart';
import 'tables/catalog_tables.dart';
import 'tables/champions_tables.dart';
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
    Evolutions,
    PokemonForms,
    Favorites,
    UserPreferences,
    SyncMetadataEntries,
    ApiCallLogs,
    ChampionsMeta,
    ChampionsPokemons,
    ChampionsLearnableMoves,
    ChampionsUsages,
  ],
  daos: [
    CatalogDao,
    ChampionsDao,
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
  int get schemaVersion => 4;

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
      if (from < 2) {
        // v2 (RD-24): detalle bajo demanda: movimientos, evolución, formas y shiny.
        await m.addColumn(pokemons, pokemons.spriteShinyUrl);
        await m.addColumn(pokemons, pokemons.artworkShinyUrl);
        await m.createTable(pokemonMoves);
        await m.createTable(evolutions);
        await m.createTable(pokemonForms);
        await m.createIndex(idxEvolutionChainId);
        await m.createIndex(idxPokemonFormSpeciesId);
      }
      if (from < 3) {
        // v3: imágenes por género.
        await m.addColumn(pokemons, pokemons.homeUrl);
        await m.addColumn(pokemons, pokemons.homeShinyUrl);
        await m.addColumn(pokemons, pokemons.femaleUrl);
        await m.addColumn(pokemons, pokemons.femaleShinyUrl);
        // Los detalles ya guardados se vuelven a pedir al abrirlos.
        await customStatement('UPDATE pokemon SET detail_synced_at = NULL');
      }
      if (from < 4) {
        // v4 (RD-35): caché de Pokémon Champions Battle Data (D12).
        await m.createTable(championsMeta);
        await m.createTable(championsPokemons);
        await m.createTable(championsLearnableMoves);
        await m.createTable(championsUsages);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
