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

  /// Busca [search] (nombre o número nacional) en PokéAPI y guarda lo que
  /// encuentre en la base; `watchPokemon` lo emite después. Devuelve cuántos
  /// Pokémon guardó. Es el respaldo cuando lo local no tiene resultados: gasta
  /// una llamada, así que quien lo use debe comprobar antes que hay servicio.
  /// Si falla lanza el `Failure` y no guarda nada.
  Future<int> searchRemote(String search);

  /// Trae y guarda el detalle de [pokemonId] (con su cadena evolutiva) en una
  /// sola llamada si falta o venció a los 3 días; si está vigente no hace nada.
  /// Si ya hay una descarga de ese Pokémon en curso se une a ella. Si falla,
  /// lanza el `Failure` correspondiente y conserva lo local.
  Future<void> syncDetail(int pokemonId);
}
