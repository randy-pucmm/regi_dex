import '../../../core/database/app_database.dart';
import '../domain/champions_info.dart';
import '../domain/champions_pokemon.dart';
import 'champions_mapper.dart';

/// Resultado de contrastar los movimientos de Champions con el version group
/// `champions` de PokéAPI.
class LearnsetCheck {
  const LearnsetCheck({
    required this.versionGroupKnown,
    required this.pokemonChecked,
    required this.movesMissingInPokeApi,
  });

  /// El version group 32 `champions` existe en los datos de referencia.
  final bool versionGroupKnown;

  /// Pokémon con movimientos del grupo 32 ya descargados, que se pudieron
  /// comparar.
  final int pokemonChecked;

  /// Movimientos de Champions que PokéAPI no lista para ese Pokémon.
  final int movesMissingInPokeApi;
}

/// Caché local de Champions: lectura para la UI, reemplazo del índice y
/// correspondencia con los ids de PokéAPI.
class ChampionsLocalSource {
  ChampionsLocalSource(this._db);

  /// Id del version group `champions` en PokéAPI.
  static const championsVersionGroupId = 32;

  final AppDatabase _db;

  /// Versión del índice guardado, o null si no hay.
  Future<String?> readDataVersion() async =>
      (await _db.championsDao.getMeta())?.dataVersion;

  /// Última confirmación del índice contra el servicio, o null si no hay.
  Future<DateTime?> readFetchedAt() async =>
      (await _db.championsDao.getMeta())?.fetchedAt;

  /// Reemplaza todo el índice por [record] en una transacción.
  Future<void> replaceIndex(ChampionsIndexRecord record) =>
      _db.championsDao.replaceIndex(
        meta: record.meta,
        pokemon: record.pokemon,
        moves: record.moves,
      );

  /// Anota que el índice sigue vigente a [at], sin tocar los datos.
  Future<void> touch(DateTime at) => _db.championsDao.touchFetchedAt(at);

  /// Pokémon guardados por nombre, como flujo.
  Stream<List<ChampionsPokemon>> watchPool() => _db.championsDao
      .watchPokemon()
      .map((rows) => [for (final row in rows) _toPokemon(row)]);

  /// Versión y fecha de los datos guardados, como flujo.
  Stream<ChampionsInfo?> watchInfo() => _db.championsDao.watchMeta().map(
    (row) => row == null
        ? null
        : ChampionsInfo(
            dataVersion: row.dataVersion,
            generatedAt: row.generatedAt,
            fetchedAt: row.fetchedAt,
            defaultSeason: row.defaultSeason,
          ),
  );

  /// Movimientos aprendibles de [showdownId] por nombre.
  Future<List<String>> learnableMoves(String showdownId) =>
      _db.championsDao.learnableMoveNames(showdownId);

  /// Relaciona con PokéAPI los Pokémon y movimientos que aún no tienen id,
  /// comparando nombres normalizados contra el catálogo local (los alias de
  /// `showdownAliases` cubren las diferencias conocidas). Se puede repetir:
  /// el catálogo puede llegar después que Champions. Devuelve cuántos Pokémon
  /// quedaron relacionados.
  Future<int> resolvePokeApiIds() async {
    final dao = _db.championsDao;
    final pendingPokemon = [
      for (final row in await dao.getPokemon())
        if (row.pokeapiPokemonId == null) row,
    ];
    final pendingMoves = {
      for (final row in await dao.getLearnableMoves())
        if (row.pokeapiMoveId == null) row.moveName,
    };
    if (pendingPokemon.isEmpty && pendingMoves.isEmpty) return 0;

    final pokemonIds = <String, int>{};
    for (final row in await _db.select(_db.pokemons).get()) {
      pokemonIds[normalizeName(row.name)] = row.id;
    }
    // Las variantes solo existen una vez sincronizado su detalle.
    for (final row in await _db.select(_db.pokemonForms).get()) {
      pokemonIds.putIfAbsent(normalizeName(row.name), () => row.pokemonId);
    }
    final resolvedPokemon = {
      for (final row in pendingPokemon)
        if (pokemonIds[pokeApiKeyFor(row.showdownId)] case final int id)
          row.showdownId: id,
    };
    await dao.setPokeapiPokemonIds(resolvedPokemon);

    if (pendingMoves.isNotEmpty) {
      final moveIds = {
        for (final row in await _db.select(_db.moves).get())
          normalizeName(row.name): row.id,
      };
      await dao.setPokeapiMoveIds({
        for (final name in pendingMoves)
          if (moveIds[normalizeName(name)] case final int id) name: id,
      });
    }
    return resolvedPokemon.length;
  }

  /// Contrasta los movimientos de Champions con los del version group 32 de
  /// PokéAPI, donde ya estén descargados. Es solo informativo: la lista de
  /// Champions es la que manda (RF-TB-03).
  Future<LearnsetCheck> checkLearnsets() async {
    final group = await (_db.select(
      _db.versionGroups,
    )..where((g) => g.id.equals(championsVersionGroupId))).getSingleOrNull();
    if (group == null) {
      return const LearnsetCheck(
        versionGroupKnown: false,
        pokemonChecked: 0,
        movesMissingInPokeApi: 0,
      );
    }
    final pokeApiMoves = <int, Set<int>>{};
    final rows = await (_db.select(
      _db.pokemonMoves,
    )..where((m) => m.versionGroupId.equals(championsVersionGroupId))).get();
    for (final row in rows) {
      (pokeApiMoves[row.pokemonId] ??= {}).add(row.moveId);
    }

    final idByShowdown = {
      for (final row in await _db.championsDao.getPokemon())
        if (row.pokeapiPokemonId != null) row.showdownId: row.pokeapiPokemonId!,
    };
    var checked = 0;
    var missing = 0;
    final championsMoves = <String, Set<int>>{};
    for (final row in await _db.championsDao.getLearnableMoves()) {
      final moveId = row.pokeapiMoveId;
      if (moveId != null) (championsMoves[row.showdownId] ??= {}).add(moveId);
    }
    for (final entry in idByShowdown.entries) {
      final listed = pokeApiMoves[entry.value];
      if (listed == null) continue;
      checked++;
      missing += (championsMoves[entry.key] ?? {}).difference(listed).length;
    }
    return LearnsetCheck(
      versionGroupKnown: true,
      pokemonChecked: checked,
      movesMissingInPokeApi: missing,
    );
  }

  ChampionsPokemon _toPokemon(ChampionsPokemonRow row) => ChampionsPokemon(
    showdownId: row.showdownId,
    name: row.name,
    showdownName: row.showdownName,
    types: row.types.split(','),
    abilities: [
      for (final ability in row.abilities.split('|'))
        if (ability.isNotEmpty) ability,
    ],
    hiddenAbility: row.hiddenAbility,
    stats: ChampionsStats(
      hp: row.hp,
      attack: row.attack,
      defense: row.defense,
      spAttack: row.spAttack,
      spDefense: row.spDefense,
      speed: row.speed,
    ),
    spriteUrl: row.spriteUrl,
    pokeapiPokemonId: row.pokeapiPokemonId,
  );
}
