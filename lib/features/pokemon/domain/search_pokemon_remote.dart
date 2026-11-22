import 'pokemon_repository.dart';

/// Caso de uso: buscar en PokéAPI lo que la base local no encontró.
///
/// Uso: llamarlo solo si la búsqueda local quedó vacía y hay servicio. Guarda
/// los resultados en la base; la pantalla los recibe porque observa la base.
class SearchPokemonRemote {
  const SearchPokemonRemote(this._repository);

  final PokemonRepository _repository;

  /// Busca [search] (nombre o número nacional) y devuelve cuántos Pokémon se
  /// guardaron. Si falla lanza el `Failure` correspondiente.
  Future<int> call(String search) => _repository.searchRemote(search);
}
