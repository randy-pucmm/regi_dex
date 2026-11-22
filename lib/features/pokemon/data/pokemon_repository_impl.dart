import '../../../core/database/daos/catalog_dao.dart';
import '../../../core/database/daos/preference_dao.dart';
import '../../../core/database/daos/reference_dao.dart';
import '../../../core/database/preference_keys.dart';
import '../../../core/sync/sync_coordinator.dart';
import '../domain/catalog_filters.dart';
import '../domain/pokemon.dart';
import '../domain/pokemon_query.dart';
import '../domain/pokemon_repository.dart';
import 'catalog_sync.dart';
import 'combine_latest.dart';
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
    required this._reference,
    required this._preferences,
  });

  final CatalogDao _catalog;
  final SyncCoordinator _coordinator;
  final CatalogSync _sync;
  final DetailSync _detail;
  final RemoteSearch _search;
  final ReferenceDao _reference;
  final PreferenceDao _preferences;

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

  /// Los valores de cada filtro desde la referencia local. Los textos salen en
  /// español cuando la referencia lo trae y, si no, en inglés legible; los
  /// tipos y los grupos huevo van por id, las habilidades por nombre.
  @override
  Stream<FilterOptions> watchFilterOptions() => _reference
      .watchFilterReference()
      .map(
        (ref) => FilterOptions(
          types: [
            for (final t in ref.types)
              FilterOption(
                id: t.id,
                key: t.name,
                label: t.nameEs ?? _readable(t.name),
              ),
          ],
          generations: [
            for (final g in ref.generations)
              FilterOption(
                id: g.id,
                key: g.name,
                label: _generationLabel(g.name, g.region),
              ),
          ],
          eggGroups: [
            for (final g in ref.eggGroups)
              FilterOption(
                id: g.id,
                key: g.name,
                label: g.nameEs ?? _readable(g.name),
              ),
          ],
          abilities:
              [
                for (final a in ref.abilities)
                  FilterOption(
                    id: a.id,
                    key: a.name,
                    label: a.nameEs ?? _readable(a.name),
                  ),
              ]..sort(
                (a, b) =>
                    a.label.toLowerCase().compareTo(b.label.toLowerCase()),
              ),
        ),
      )
      .distinct();

  /// Pokémon guardados frente al total informado en la última sincronización
  /// de referencia. Vuelve a emitir al cambiar cualquiera de los dos.
  @override
  Stream<CatalogAvailability> watchAvailability() => combineLatest2(
    _catalog.watchPokemonCount(),
    _preferences.watchValue(PreferenceKeys.catalogTotal),
    (count, total) =>
        CatalogAvailability(available: count, total: int.tryParse(total ?? '')),
  ).distinct();

  /// Lee la consulta guardada; ante cualquier problema, la de por defecto.
  @override
  Future<PokemonQuery> loadQuery() async {
    try {
      return PokemonQuery.decode(
        await _preferences.getValue(PreferenceKeys.catalogQuery),
      );
    } on Object {
      return const PokemonQuery();
    }
  }

  /// Guarda [query] en `user_preference`; la de por defecto borra la clave.
  @override
  Future<void> saveQuery(PokemonQuery query) => query.isDefault
      ? _preferences.remove(PreferenceKeys.catalogQuery)
      : _preferences.setValue(PreferenceKeys.catalogQuery, query.encode());

  /// Respaldo online de la búsqueda: guarda en la base lo que PokéAPI encuentre.
  @override
  Future<int> searchRemote(String search) async {
    final term = SearchTerm.parse(search);
    return term == null ? 0 : _search.run(term);
  }

  /// Traduce la consulta del dominio (búsqueda, filtros y orden) a lo que
  /// entiende el DAO.
  CatalogCriteria _criteriaOf(PokemonQuery query) {
    final term = query.term;
    return CatalogCriteria(
      number: term is SearchNumber ? term.number : null,
      namePart: term is SearchName ? term.text : null,
      typeIds: query.types,
      generationIds: query.generations,
      eggGroupIds: query.eggGroups,
      abilityIds: query.abilities,
      order: switch (query.sort) {
        PokemonSort.number => CatalogOrder.number,
        PokemonSort.name => CatalogOrder.name,
        PokemonSort.baseTotal => CatalogOrder.baseTotal,
      },
      descending: query.descending,
    );
  }

  /// Descarga el detalle de [pokemonId] solo si falta o venció (3 días).
  @override
  Future<void> syncDetail(int pokemonId) async {
    await _detail.sync(pokemonId);
  }
}

/// Nombre de PokéAPI en texto legible: `no-eggs` pasa a `No eggs`.
String _readable(String name) {
  final text = name.replaceAll('-', ' ');
  return text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}

/// `generation-iv` y `sinnoh` pasan a `Gen. IV · Sinnoh`; sin región, solo la
/// generación.
String _generationLabel(String name, String? region) {
  final roman = name.replaceFirst('generation-', '').toUpperCase();
  final place = region == null || region.isEmpty
      ? ''
      : ' · ${_readable(region)}';
  return 'Gen. $roman$place';
}
