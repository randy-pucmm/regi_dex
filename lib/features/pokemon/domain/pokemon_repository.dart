import 'catalog_filters.dart';
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

  /// Los valores que ofrece cada filtro (tipos, generaciones, grupos huevo y
  /// habilidades), desde la referencia local; vacío hasta que se descarga.
  Stream<FilterOptions> watchFilterOptions();

  /// Cuántos Pokémon hay en el dispositivo frente al total de la Pokédex, para
  /// avisar si el catálogo local está incompleto (RF-FIL-05).
  Stream<CatalogAvailability> watchAvailability();

  /// La búsqueda, los filtros y el orden de la última sesión (RF-FIL-04), o la
  /// consulta por defecto si no hay nada guardado o está dañado.
  Future<PokemonQuery> loadQuery();

  /// Guarda [query] para la próxima sesión; la consulta por defecto borra lo
  /// guardado.
  Future<void> saveQuery(PokemonQuery query);

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
