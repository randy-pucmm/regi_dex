import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/champions_tables.dart';

part 'champions_dao.g.dart';

/// Acceso a la caché de Champions Battle Data (D12).
@DriftAccessor(
  tables: [ChampionsMeta, ChampionsPokemons, ChampionsLearnableMoves],
)
class ChampionsDao extends DatabaseAccessor<AppDatabase>
    with _$ChampionsDaoMixin {
  ChampionsDao(super.attachedDatabase);

  /// Clave de la única fila de `champions_meta`.
  static const metaKey = 'index';

  /// Versión del índice guardado, o null si nunca se descargó.
  Future<ChampionsMetaRow?> getMeta() => (select(
    championsMeta,
  )..where((m) => m.key.equals(metaKey))).getSingleOrNull();

  /// Versión del índice guardado como flujo.
  Stream<ChampionsMetaRow?> watchMeta() => (select(
    championsMeta,
  )..where((m) => m.key.equals(metaKey))).watchSingleOrNull();

  /// Reemplaza todo el índice por [meta], [pokemon] y [moves] en una sola
  /// transacción: o queda el índice nuevo completo o el anterior intacto.
  Future<void> replaceIndex({
    required ChampionsMetaCompanion meta,
    required List<ChampionsPokemonsCompanion> pokemon,
    required List<ChampionsLearnableMovesCompanion> moves,
  }) => transaction(() async {
    await delete(championsLearnableMoves).go();
    await delete(championsPokemons).go();
    await batch((b) {
      b.insertAll(championsPokemons, pokemon);
      b.insertAll(championsLearnableMoves, moves);
    });
    await into(championsMeta).insertOnConflictUpdate(meta);
  });

  /// Anota que el índice se confirmó vigente en [at], sin tocar los datos.
  Future<void> touchFetchedAt(DateTime at) =>
      (update(championsMeta)..where((m) => m.key.equals(metaKey))).write(
        ChampionsMetaCompanion(fetchedAt: Value(at)),
      );

  /// Pokémon del índice por nombre, como flujo.
  Stream<List<ChampionsPokemonRow>> watchPokemon() => (select(
    championsPokemons,
  )..orderBy([(p) => OrderingTerm.asc(p.name)])).watch();

  /// Pokémon del índice.
  Future<List<ChampionsPokemonRow>> getPokemon() =>
      select(championsPokemons).get();

  /// Nombres de los movimientos de [showdownId] por orden alfabético.
  Future<List<String>> learnableMoveNames(String showdownId) async {
    final rows =
        await (select(championsLearnableMoves)
              ..where((m) => m.showdownId.equals(showdownId))
              ..orderBy([(m) => OrderingTerm.asc(m.moveName)]))
            .get();
    return [for (final row in rows) row.moveName];
  }

  /// Movimientos aprendibles de todos los Pokémon.
  Future<List<ChampionsLearnableMoveRow>> getLearnableMoves() =>
      select(championsLearnableMoves).get();

  /// Guarda el id de PokéAPI de cada Pokémon ([ids]: showdownId → id).
  Future<void> setPokeapiPokemonIds(Map<String, int> ids) => batch((b) {
    for (final entry in ids.entries) {
      b.update(
        championsPokemons,
        ChampionsPokemonsCompanion(pokeapiPokemonId: Value(entry.value)),
        where: (p) => p.showdownId.equals(entry.key),
      );
    }
  });

  /// Guarda el id de PokéAPI de cada movimiento ([ids]: nombre → id).
  Future<void> setPokeapiMoveIds(Map<String, int> ids) => batch((b) {
    for (final entry in ids.entries) {
      b.update(
        championsLearnableMoves,
        ChampionsLearnableMovesCompanion(pokeapiMoveId: Value(entry.value)),
        where: (m) => m.moveName.equals(entry.key),
      );
    }
  });
}
