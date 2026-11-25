import 'pokemon_repository.dart';

/// Caso de uso: traer el detalle de un Pokémon al abrirlo (OF-20, PS-03).
///
/// Uso: llamarlo al abrir un detalle y seguir mostrando lo local mientras
/// tanto; la pantalla se actualiza sola porque observa la base. Si no hay
/// servicio conviene omitirlo. Un fallo lanza el `Failure` y deja lo local.
class SyncPokemonDetail {
  const SyncPokemonDetail(this._repository);

  final PokemonRepository _repository;

  /// Descarga el detalle de [pokemonId] si falta o tiene 3 días o más.
  Future<void> call(int pokemonId) => _repository.syncDetail(pokemonId);
}
