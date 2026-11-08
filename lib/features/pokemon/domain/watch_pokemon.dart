import 'pokemon.dart';
import 'pokemon_query.dart';
import 'pokemon_repository.dart';

/// Caso de uso: observar el catálogo. Sin argumentos devuelve todo.
class WatchPokemon {
  const WatchPokemon(this._repository);

  final PokemonRepository _repository;

  Stream<List<Pokemon>> call([PokemonQuery query = const PokemonQuery()]) =>
      _repository.watchPokemon(query);
}
