import '../../../core/database/daos/catalog_dao.dart';
import '../../../core/sync/sync_coordinator.dart';
import '../domain/pokemon.dart';
import '../domain/pokemon_query.dart';
import '../domain/pokemon_repository.dart';
import 'catalog_sync.dart';
import 'pokemon_entity_mapper.dart';

/// Repositorio del catálogo sobre Drift (fuente de verdad) y la
/// sincronización del catálogo (D06).
class PokemonRepositoryImpl implements PokemonRepository {
  PokemonRepositoryImpl({
    required this._catalog,
    required this._coordinator,
    required this._sync,
  });

  final CatalogDao _catalog;
  final SyncCoordinator _coordinator;
  final CatalogSync _sync;

  /// Pokémon de la base local como entidades de dominio. Por ahora [query]
  /// está vacía y devuelve todo el catálogo por número nacional.
  @override
  Stream<List<Pokemon>> watchPokemon(PokemonQuery query) => _catalog
      .watchPokemonWithTypes()
      .map((items) => [for (final item in items) pokemonFromRows(item)]);

  /// Pide la sincronización al coordinador, que une las solicitudes
  /// simultáneas en una sola ejecución (single-flight).
  @override
  Future<void> refresh() =>
      _coordinator.run<void>(CatalogSync.resourceKey, _sync.execute);
}
