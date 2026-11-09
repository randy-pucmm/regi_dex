import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/connectivity/service_status.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/pokemon.dart';

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

/// Con datos se muestran aunque la sync siga en curso o haya fallado: el
/// estado de la conexión lo dice el LED.
CatalogState catalogStateOf({
  required AsyncValue<List<Pokemon>> pokemon,
  required SyncStatus sync,
  required ServiceStatus service,
}) {
  if (pokemon.hasError) return const CatalogError();
  final list = pokemon.value;
  if (list == null) return const CatalogLoading();
  if (list.isNotEmpty) return CatalogLoaded(list);
  if (sync == SyncStatus.sincronizando) return const CatalogLoading();
  if (service == ServiceStatus.offline) return const CatalogEmpty();
  final failed =
      sync == SyncStatus.fallida || sync == SyncStatus.esperandoReintento;
  if (failed || service == ServiceStatus.servicioNoDisponible) {
    return const CatalogError();
  }
  return const CatalogLoading();
}

final _pokemonProvider = StreamProvider<List<Pokemon>>(
  (ref) => ref.watch(watchPokemonProvider)(),
);

final catalogStateProvider = Provider<CatalogState>(
  (ref) => catalogStateOf(
    pokemon: ref.watch(_pokemonProvider),
    sync: ref.watch(syncStatusProvider).value ?? SyncStatus.inactiva,
    service:
        ref.watch(serviceStatusProvider).value?.status ??
        ServiceStatus.verificando,
  ),
);
