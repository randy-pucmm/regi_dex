import 'package:clock/clock.dart';

import '../../../core/database/daos/catalog_dao.dart';
import '../../../core/database/daos/reference_dao.dart';
import '../domain/pokemon_detail.dart';
import '../domain/pokemon_detail_repository.dart';
import '../domain/evolution_chain.dart';
import '../domain/pokemon.dart';
import '../domain/pokemon_move.dart';
import '../domain/type_chart.dart';
import 'catalog_sync.dart';
import 'evolution_mapper.dart';
import 'pokemon_detail_mapper.dart';
import 'pokemon_entity_mapper.dart';
import 'pokemon_remote_source.dart';

class PokemonDetailRepositoryImpl implements PokemonDetailRepository {
  PokemonDetailRepositoryImpl({
    required this._catalog,
    required this._reference,
    required this._remote,
  });

  final CatalogDao _catalog;
  final ReferenceDao _reference;
  final PokemonRemoteSource _remote;

  @override
  Stream<PokemonDetail?> watchDetail(int id) =>
      _catalog.watchPokemonDetail(id).map((rows) {
        if (rows == null) return null;
        return PokemonDetail(
          pokemon: pokemonFromRows((pokemon: rows.pokemon, types: rows.types)),
          height: rows.pokemon.height,
          weight: rows.pokemon.weight,
          stats: {for (final s in rows.stats) s.statId: s.baseStat},
          abilities: [
            for (final a in rows.abilities)
              PokemonAbilityRef(
                name: a.ability.name,
                nameEs: a.ability.nameEs,
                isHidden: a.isHidden,
                shortEffect: a.ability.shortEffect,
              ),
          ],
        );
      });

  @override
  Future<void> refreshDetail(int id) async {
    final syncedAt = (await _catalog.getPokemon(id))?.detailSyncedAt;
    final fresh =
        syncedAt != null &&
        clock.now().difference(syncedAt) < CatalogSync.catalogMaxAge;
    if (fresh && await _catalog.hasMoves(id)) return;
    final record = mapPokemonDetail(await _remote.fetchDetail(id));
    await _catalog.saveDetail(
      pokemonId: record.pokemonId,
      speciesId: record.speciesId,
      syncedAt: clock.now(),
      speciesNameEs: record.speciesNameEs,
      genusEs: record.genusEs,
      abilities: record.abilities,
      moves: record.moves,
      chainSpeciesIds: record.chainSpeciesIds,
      evolutions: record.evolutions,
    );
  }

  @override
  Future<MoveGames> moveGames(int pokemonId) async => MoveGames(
    games: [
      for (final game in await _catalog.getMoveGames(pokemonId))
        MoveGame(id: game.id, name: game.name),
    ],
    defaultId: await _catalog.getDefaultMoveGame(pokemonId),
  );

  @override
  Future<MovePage> moves(
    int pokemonId,
    MoveMethod method, {
    required int versionGroupId,
    required int page,
  }) async {
    final total = await _catalog.countMoves(
      pokemonId,
      versionGroupId: versionGroupId,
      methodId: method.id,
    );
    final rows = await _catalog.getMoves(
      pokemonId,
      versionGroupId: versionGroupId,
      methodId: method.id,
      limit: movesPageSize,
      offset: page * movesPageSize,
    );
    return MovePage(
      page: page,
      totalPages: (total / movesPageSize).ceil(),
      moves: [
        for (final row in rows)
          PokemonMove(
            id: row.moveId,
            name: row.name,
            level: row.level,
            category: MoveCategory.fromId(row.damageClassId),
            typeName: row.typeName,
            typeNameEs: row.typeNameEs,
            power: row.power,
            accuracy: row.accuracy,
            pp: row.pp,
          ),
      ],
    );
  }

  @override
  Stream<TypeChart> watchTypeChart() =>
      _reference.watchEfficacies().asyncMap((efficacies) async {
        return TypeChart(
          types: [
            for (final t in await _reference.getTypes())
              PokemonTypeRef(id: t.id, name: t.name, nameEs: t.nameEs),
          ],
          percents: {
            for (final e in efficacies)
              (e.attackingTypeId, e.defendingTypeId): e.factor,
          },
        );
      });

  @override
  Stream<EvolutionChain?> watchEvolutions(int pokemonId) => _catalog
      .watchEvolutions(pokemonId)
      .map((rows) => rows == null ? null : evolutionChainFromRows(rows));
}
