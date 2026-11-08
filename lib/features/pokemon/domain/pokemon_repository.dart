import 'pokemon.dart';
import 'pokemon_query.dart';

/// Acceso al catálogo de Pokémon. La fuente de verdad es la base local; los
/// widgets nunca ven respuestas de GraphQL (OF-16, OF-17, OF-18).
abstract interface class PokemonRepository {
  /// Pokémon que cumplen [query], desde la base local. Emite la lista actual
  /// al suscribirse y vuelve a emitir cada vez que cambia el catálogo, por
  /// ejemplo con cada lote de una sincronización.
  Stream<List<Pokemon>> watchPokemon(PokemonQuery query);

  /// Pide una sincronización del catálogo y espera a que termine. Si ya hay
  /// una en curso se une a ella. Si falla, lanza el `Failure` correspondiente.
  Future<void> refresh();
}
