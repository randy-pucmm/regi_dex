import '../../../core/database/daos/catalog_dao.dart';
import '../../../core/sync/sync_coordinator.dart';
import '../domain/pokemon.dart';
import '../domain/pokemon_query.dart';
import '../domain/pokemon_repository.dart';
import 'catalog_sync.dart';
import 'detail_sync.dart';
import 'pokemon_entity_mapper.dart';
import 'remote_search.dart';

/// Repositorio del catálogo sobre Drift (fuente de verdad) y la
/// sincronización del catálogo (D06).
class PokemonRepositoryImpl implements PokemonRepository {
  PokemonRepositoryImpl({
    required this._catalog,
    required this._coordinator,
    required this._sync,
    required this._detail,
    required this._search,
  });

  final CatalogDao _catalog;
  final SyncCoordinator _coordinator;
  final CatalogSync _sync;
  final DetailSync _detail;
  final RemoteSearch _search;

  /// Pokémon de la base local que cumplen [query], como entidades de dominio y
  /// por número nacional; con la consulta vacía, todo el catálogo. Solo emite
  /// cuando la lista cambia: guardar la referencia toca la tabla de tipos pero
  /// no debe reconstruir la pantalla.
  @override
  Stream<List<Pokemon>> watchPokemon(PokemonQuery query) => _catalog
      .watchPokemonWithTypes(_criteriaOf(query))
      .map((items) => [for (final item in items) pokemonFromRows(item)])
      .distinct(samePokemonList);

  /// Pide la sincronización al coordinador, que une las solicitudes
  /// simultáneas en una sola ejecución (single-flight).
  @override
  Future<void> refresh() =>
      _coordinator.run<void>(CatalogSync.resourceKey, _sync.execute);

  /// Respaldo online de la búsqueda: guarda en la base lo que PokéAPI encuentre.
  @override
  Future<int> searchRemote(String search) async {
    final term = SearchTerm.parse(search);
    return term == null ? 0 : _search.run(term);
  }

  /// Traduce la búsqueda del dominio a lo que entiende el DAO.
  CatalogCriteria _criteriaOf(PokemonQuery query) => switch (query.term) {
    SearchNumber(:final number) => CatalogCriteria(number: number),
    SearchName(:final text) => CatalogCriteria(namePart: text),
    null => const CatalogCriteria(),
  };

  /// Descarga el detalle de [pokemonId] solo si falta o venció (3 días).
  @override
  Future<void> syncDetail(int pokemonId) async {
    await _detail.sync(pokemonId);
  }
}
