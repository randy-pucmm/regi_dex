import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/connectivity/service_status.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/catalog_filters.dart';
import '../domain/pokemon.dart';
import '../domain/pokemon_query.dart';

/// Categoría de filtro del catálogo.
enum FilterCategory { types, generations, eggGroups, abilities }

/// La consulta guardada en la última sesión (RF-FIL-04). Mientras se lee, la
/// lista del catálogo espera para no mostrar un instante sin filtros.
final savedQueryProvider = FutureProvider<PokemonQuery>(
  (ref) => ref.watch(pokemonRepositoryProvider).loadQuery(),
);

/// Consulta vigente del catálogo: búsqueda, filtros y orden. Arranca con lo
/// guardado en la sesión anterior y guarda cada cambio. La búsqueda se
/// actualiza con un debounce de 350 ms (RF-CAT-03): mientras se escribe no se
/// consulta la base; los filtros y el orden cambian al instante.
class CatalogSearch extends Notifier<PokemonQuery> {
  /// Espera tras la última tecla antes de buscar.
  static const debounce = Duration(milliseconds: 350);

  Timer? _timer;

  @override
  PokemonQuery build() {
    ref.onDispose(() => _timer?.cancel());
    return ref.watch(savedQueryProvider).value ?? const PokemonQuery();
  }

  /// Programa la búsqueda de [text] para dentro de [debounce]; una pulsación
  /// nueva cancela la anterior.
  void setText(String text) {
    _timer?.cancel();
    _timer = Timer(debounce, () => _emit(state.copyWith(search: text)));
  }

  /// Borra la búsqueda al instante, sin esperar el debounce.
  void clear() {
    _timer?.cancel();
    _emit(state.copyWith(search: ''));
  }

  /// Agrega o quita [id] del filtro [category].
  void toggle(FilterCategory category, int id) {
    final current = switch (category) {
      FilterCategory.types => state.types,
      FilterCategory.generations => state.generations,
      FilterCategory.eggGroups => state.eggGroups,
      FilterCategory.abilities => state.abilities,
    };
    final next = current.contains(id)
        ? (Set.of(current)..remove(id))
        : (Set.of(current)..add(id));
    _emit(switch (category) {
      FilterCategory.types => state.copyWith(types: next),
      FilterCategory.generations => state.copyWith(generations: next),
      FilterCategory.eggGroups => state.copyWith(eggGroups: next),
      FilterCategory.abilities => state.copyWith(abilities: next),
    });
  }

  /// Ordena por [sort]; elegir el mismo campo otra vez invierte el sentido.
  void sortBy(PokemonSort sort) {
    _emit(
      sort == state.sort
          ? state.copyWith(descending: !state.descending)
          : state.copyWith(sort: sort, descending: false),
    );
  }

  /// Cambia el sentido del orden actual.
  void toggleDirection() =>
      _emit(state.copyWith(descending: !state.descending));

  /// Quita todos los filtros de categoría; conserva la búsqueda y el orden.
  void clearFilters() => _emit(state.withoutFilters());

  void _emit(PokemonQuery query) {
    state = query;
    unawaited(_save(query));
  }

  Future<void> _save(PokemonQuery query) async {
    try {
      await ref.read(pokemonRepositoryProvider).saveQuery(query);
    } on Object {
      // No guardar no debe romper la pantalla: la próxima sesión parte de cero.
    }
  }
}

final catalogQueryProvider = NotifierProvider<CatalogSearch, PokemonQuery>(
  CatalogSearch.new,
);

/// Pokémon de la base local que cumplen la consulta vigente. Espera a que se
/// lea la consulta guardada.
final catalogResultsProvider = StreamProvider<List<Pokemon>>((ref) async* {
  final hydrated = ref.watch(savedQueryProvider.future);
  final query = ref.watch(catalogQueryProvider);
  final watch = ref.watch(watchPokemonProvider);
  await hydrated;
  // Si al leer lo guardado la consulta cambió, este resultado ya no sirve: el
  // proveedor se vuelve a ejecutar con la consulta nueva.
  if (!ref.mounted || ref.read(catalogQueryProvider) != query) return;
  yield* watch(query);
});

/// Los valores de cada filtro, desde la referencia local.
final filterOptionsProvider = StreamProvider<FilterOptions>(
  (ref) => ref.watch(pokemonRepositoryProvider).watchFilterOptions(),
);

/// Pokémon guardados frente al total de la Pokédex.
final catalogAvailabilityProvider = StreamProvider<CatalogAvailability>(
  (ref) => ref.watch(pokemonRepositoryProvider).watchAvailability(),
);

/// Respaldo remoto de la búsqueda (RF-CAT-03). El estado es `true` mientras
/// consulta a PokéAPI.
///
/// Se dispara una vez por texto cuando la base local no devuelve nada, hay
/// servicio y el catálogo no se está descargando (en ese caso el Pokémon puede
/// llegar solo). Guarda los resultados en la base: la pantalla los recibe
/// porque observa la base, no la respuesta. Un fallo se ignora: queda en el
/// registro de llamadas y la búsqueda sigue sin resultados.
class CatalogRemoteSearch extends Notifier<bool> {
  String? _attempted;

  @override
  bool build() {
    // Solo se evalúa cuando cambia el resultado (que siempre sigue a un cambio
    // de consulta), nunca con una lista que aún es de la consulta anterior.
    ref.listen(catalogResultsProvider, (_, _) => _evaluate());
    ref.listen(serviceStatusProvider, (_, _) => _evaluate());
    ref.listen(syncStatusProvider, (_, _) => _evaluate());
    return false;
  }

  void _evaluate() {
    final search = ref.read(catalogQueryProvider).search.trim();
    if (search.isEmpty) {
      _attempted = null;
      return;
    }
    if (search == _attempted) return;
    final results = ref.read(catalogResultsProvider);
    final service = ref.read(serviceStatusProvider).value?.status;
    final sync = ref.read(syncStatusProvider).value;
    final noLocalResults = results.hasValue && results.requireValue.isEmpty;
    if (!noLocalResults ||
        results.isLoading ||
        service != ServiceStatus.online ||
        sync == SyncStatus.sincronizando) {
      return;
    }
    _attempted = search;
    unawaited(_run(search));
  }

  Future<void> _run(String search) async {
    if (!ref.mounted) return;
    state = true;
    try {
      await ref.read(searchPokemonRemoteProvider)(search);
    } on Object {
      // Sin respuesta útil: se queda en «Sin resultados».
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

final catalogRemoteSearchProvider = NotifierProvider<CatalogRemoteSearch, bool>(
  CatalogRemoteSearch.new,
);
