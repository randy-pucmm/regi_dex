import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/connectivity/service_status.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/pokemon.dart';
import '../domain/pokemon_query.dart';
import 'catalog_search.dart';

sealed class CatalogState {
  const CatalogState();
}

final class CatalogLoading extends CatalogState {
  const CatalogLoading();
}

final class CatalogLoaded extends CatalogState {
  const CatalogLoaded(this.pokemon);

  final List<Pokemon> pokemon;
}

/// Sin catálogo y sin red: la primera ejecución sin conexión.
final class CatalogEmpty extends CatalogState {
  const CatalogEmpty();
}

final class CatalogError extends CatalogState {
  const CatalogError();
}

/// Hay una búsqueda y nada la cumple. Es independiente de la sync: el catálogo
/// puede estar completo y aun así no tener coincidencias.
final class CatalogNoResults extends CatalogState {
  const CatalogNoResults({
    required this.search,
    required this.searching,
    required this.offline,
  });

  /// Texto buscado, sin espacios sobrantes.
  final String search;

  /// Aún se puede encontrar algo: se consulta PokéAPI o el catálogo se descarga.
  final bool searching;

  /// Sin conexión: solo se buscó en lo ya descargado.
  final bool offline;
}

/// Con datos se muestran aunque la sync siga en curso o haya fallado: el
/// estado de la conexión lo dice el LED. Con una búsqueda activa y sin
/// resultados el estado es [CatalogNoResults], sin importar la sync.
/// [searchingRemote] indica que se está consultando PokéAPI.
CatalogState catalogStateOf({
  required AsyncValue<List<Pokemon>> pokemon,
  required SyncStatus sync,
  required ServiceStatus service,
  PokemonQuery query = const PokemonQuery(),
  bool searchingRemote = false,
}) {
  if (pokemon.hasError) return const CatalogError();
  final list = pokemon.value;
  if (list == null) return const CatalogLoading();
  if (list.isNotEmpty) return CatalogLoaded(list);
  if (query.term != null) {
    return CatalogNoResults(
      search: query.search.trim(),
      searching: searchingRemote || sync == SyncStatus.sincronizando,
      offline: service == ServiceStatus.offline,
    );
  }
  if (sync == SyncStatus.sincronizando) return const CatalogLoading();
  if (service == ServiceStatus.offline) return const CatalogEmpty();
  final failed =
      sync == SyncStatus.fallida || sync == SyncStatus.esperandoReintento;
  if (failed || service == ServiceStatus.servicioNoDisponible) {
    return const CatalogError();
  }
  return const CatalogLoading();
}

final catalogStateProvider = Provider<CatalogState>(
  (ref) => catalogStateOf(
    pokemon: ref.watch(catalogResultsProvider),
    sync: ref.watch(syncStatusProvider).value ?? SyncStatus.inactiva,
    service:
        ref.watch(serviceStatusProvider).value?.status ??
        ServiceStatus.verificando,
    query: ref.watch(catalogQueryProvider),
    searchingRemote: ref.watch(catalogRemoteSearchProvider),
  ),
);
