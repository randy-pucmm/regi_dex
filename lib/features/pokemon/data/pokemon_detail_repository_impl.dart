import '../../../core/database/daos/catalog_dao.dart';
import '../domain/pokemon_detail.dart';
import '../domain/pokemon_detail_repository.dart';
import 'pokemon_entity_mapper.dart';

class PokemonDetailRepositoryImpl implements PokemonDetailRepository {
  PokemonDetailRepositoryImpl({required this._catalog});

  final CatalogDao _catalog;

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
}
