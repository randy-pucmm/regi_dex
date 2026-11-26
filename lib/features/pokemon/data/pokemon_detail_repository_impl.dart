import '../../../core/database/daos/catalog_dao.dart';
import '../../../core/database/daos/reference_dao.dart';
import '../domain/pokemon_detail.dart';
import '../domain/pokemon_detail_repository.dart';
import '../domain/evolution_chain.dart';
import '../domain/pokemon.dart';
import '../domain/pokemon_move.dart';
import '../domain/type_chart.dart';
import '../domain/title_case.dart';
import 'evolution_mapper.dart';
import 'pokemon_entity_mapper.dart';

class PokemonDetailRepositoryImpl implements PokemonDetailRepository {
  PokemonDetailRepositoryImpl({
    required this._catalog,
    required this._reference,
  });

  final CatalogDao _catalog;
  final ReferenceDao _reference;

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
          speciesId: rows.pokemon.speciesId,
          shinyUrl: rows.pokemon.artworkShinyUrl ?? rows.pokemon.spriteShinyUrl,
          eggGroups: [for (final g in rows.eggGroups) g.nameEs ?? g.name],
          forms: [
            for (final f in rows.forms)
              PokemonFormRef(
                id: f.pokemonId,
                label: (f.formName ?? '').isEmpty
                    ? 'Normal'
                    : titleCase(f.formName!),
              ),
          ],
          genderArt: rows.pokemon.femaleUrl == null
              ? null
              : (
                  male: rows.pokemon.homeUrl,
                  maleShiny: rows.pokemon.homeShinyUrl,
                  female: rows.pokemon.femaleUrl!,
                  femaleShiny: rows.pokemon.femaleShinyUrl,
                ),
        );
      });

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
