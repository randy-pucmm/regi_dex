import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connectivity/budgeted_health_checker.dart';
import '../core/connectivity/connectivity_monitor.dart';
import '../core/connectivity/health_checker.dart';
import '../core/connectivity/network_source.dart';
import '../core/connectivity/service_status.dart';
import '../core/database/app_database.dart';
import '../core/error/failure.dart';
import '../core/images/image_prefetcher.dart';
import '../core/network/operation_loader.dart';
import '../core/network/poke_api_client.dart';
import '../core/network/poke_api_config.dart';
import '../core/sync/api_budget.dart';
import '../core/sync/sync_coordinator.dart';
import '../core/sync/sync_status.dart';
import '../features/pokemon/data/catalog_local_source.dart';
import '../features/pokemon/data/catalog_sync.dart';
import '../features/pokemon/data/detail_sync.dart';
import '../features/pokemon/data/image_sync.dart';
import '../features/pokemon/data/integrity_checker.dart';
import '../features/pokemon/data/pokemon_detail_repository_impl.dart';
import '../features/pokemon/data/pokemon_remote_source.dart';
import '../features/pokemon/data/pokemon_repository_impl.dart';
import '../features/pokemon/data/remote_search.dart';
import '../features/pokemon/domain/evolution_chain.dart';
import '../features/pokemon/domain/pokemon_detail.dart';
import '../features/pokemon/domain/pokemon_detail_repository.dart';
import '../features/pokemon/domain/pokemon_move.dart';
import '../features/pokemon/domain/pokemon_repository.dart';
import '../features/pokemon/domain/refresh_catalog.dart';
import '../features/pokemon/domain/search_pokemon_remote.dart';
import '../features/pokemon/domain/sync_pokemon_detail.dart';
import '../features/pokemon/domain/type_chart.dart';
import '../features/pokemon/domain/watch_pokemon.dart';
import 'image_providers.dart';

/// Base de datos local, única para toda la app. Las pruebas la sobrescriben
/// con una base en memoria.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.open();
  ref.onDispose(database.close);
  return database;
});

/// Endpoint GraphQL de PokéAPI. Se cambia con `--dart-define=POKEAPI_ENDPOINT=...`
/// o sobrescribiendo el provider (simulador de API caída, PA-08).
final pokeApiEndpointProvider = Provider<Uri>(
  (ref) => Uri.parse(
    const String.fromEnvironment(
      'POKEAPI_ENDPOINT',
      defaultValue: defaultPokeApiEndpoint,
    ),
  ),
);

/// Cargador de los documentos `.graphql`.
final operationLoaderProvider = Provider<OperationLoader>(
  (ref) => OperationLoader(),
);

/// Cliente GraphQL de PokéAPI sobre el endpoint configurado.
final pokeApiClientProvider = Provider<PokeApiClient>((ref) {
  final client = PokeApiClient(
    endpoint: ref.watch(pokeApiEndpointProvider),
    loader: ref.watch(operationLoaderProvider),
  );
  ref.onDispose(client.dispose);
  return client;
});

/// Eventos de red del dispositivo (`connectivity_plus`).
final networkSourceProvider = Provider<NetworkSource>(
  (ref) => ConnectivityPlusNetworkSource(),
);

/// Presupuesto de llamadas a PokéAPI (90 por ventana móvil de 60 min).
final apiBudgetProvider = Provider<ApiBudget>(
  (ref) => ApiBudget(log: ref.watch(appDatabaseProvider).apiCallLogDao),
);

/// Health-check contra PokéAPI, dentro del presupuesto de llamadas.
final healthCheckerProvider = Provider<HealthChecker>(
  (ref) => BudgetedHealthChecker(
    inner: GraphqlHealthChecker(ref.watch(pokeApiClientProvider)),
    budget: ref.watch(apiBudgetProvider),
  ),
);

/// Monitor de conectividad, activo mientras exista el provider.
final connectivityMonitorProvider = Provider<ConnectivityMonitor>((ref) {
  final monitor = ConnectivityMonitor(
    network: ref.watch(networkSourceProvider),
    healthChecker: ref.watch(healthCheckerProvider),
    calls: ref.watch(pokeApiClientProvider).calls,
  );
  unawaited(monitor.start());
  ref.onDispose(monitor.dispose);
  return monitor;
});

/// Estado de conectividad para el indicador global.
final serviceStatusProvider = StreamProvider<ConnectivitySnapshot>(
  (ref) => ref.watch(connectivityMonitorProvider).snapshots,
);

/// Coordinador de sincronizaciones: single-flight por recurso y `sync_metadata`.
final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final coordinator = SyncCoordinator(
    metadata: ref.watch(appDatabaseProvider).syncMetadataDao,
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Estado de sync de todos los recursos (`sync_metadata`), como flujo. Lo
/// observan la descarga de imágenes y los reintentos; las pruebas de pantallas
/// lo sustituyen por un flujo fijo.
final syncMetadataStreamProvider = Provider<Stream<List<SyncMetadataRow>>>(
  (ref) => ref.watch(appDatabaseProvider).syncMetadataDao.watchAll(),
);

/// Estado de la sincronización para el indicador global.
final syncStatusProvider = StreamProvider<SyncStatus>(
  (ref) => ref.watch(syncCoordinatorProvider).statuses,
);

/// Llamadas del catálogo a PokéAPI, dentro del presupuesto de llamadas.
final pokemonRemoteSourceProvider = Provider<PokemonRemoteSource>(
  (ref) => PokemonRemoteSource(
    client: ref.watch(pokeApiClientProvider),
    budget: ref.watch(apiBudgetProvider),
  ),
);

/// Sincronización del catálogo. Se ejecuta con
/// `coordinator.run(CatalogSync.resourceKey, sync.execute)`.
final catalogSyncProvider = Provider<CatalogSync>(
  (ref) => CatalogSync(
    remote: ref.watch(pokemonRemoteSourceProvider),
    local: CatalogLocalSource(ref.watch(appDatabaseProvider)),
    coordinator: ref.watch(syncCoordinatorProvider),
  ),
);

/// Sincronización del detalle bajo demanda (una llamada por Pokémon).
final detailSyncProvider = Provider<DetailSync>(
  (ref) => DetailSync(
    remote: ref.watch(pokemonRemoteSourceProvider),
    local: CatalogLocalSource(ref.watch(appDatabaseProvider)),
    coordinator: ref.watch(syncCoordinatorProvider),
  ),
);

/// Descarga de imágenes a la caché de disco. La caché se abre al descargar,
/// no al observar el avance.
final imagePrefetcherProvider = Provider<ImagePrefetcher>((ref) {
  final prefetcher = ImagePrefetcher(
    isCached: (url) async =>
        await ref.read(imageCacheManagerProvider).getFileFromCache(url) != null,
    download: (url) => ref.read(imageCacheManagerProvider).getSingleFile(url),
  );
  ref.onDispose(prefetcher.dispose);
  return prefetcher;
});

/// Avance de la descarga de imágenes en segundo plano.
final imageProgressProvider = StreamProvider<ImagePrefetchProgress>(
  (ref) => ref.watch(imagePrefetcherProvider).progress,
);

/// Descarga en segundo plano de los sprites del catálogo (no gasta el
/// presupuesto de PokéAPI).
final imageSyncProvider = Provider<ImageSync>(
  (ref) => ImageSync(
    catalog: ref.watch(appDatabaseProvider).catalogDao,
    prefetcher: ref.watch(imagePrefetcherProvider),
    coordinator: ref.watch(syncCoordinatorProvider),
  ),
);

/// Verificación de integridad del catálogo (OF-19..21): detecta filas
/// alteradas en el dispositivo y las restaura desde PokéAPI.
final integrityCheckerProvider = Provider<IntegrityChecker>(
  (ref) => IntegrityChecker(
    remote: ref.watch(pokemonRemoteSourceProvider),
    local: CatalogLocalSource(ref.watch(appDatabaseProvider)),
    metadata: ref.watch(appDatabaseProvider).syncMetadataDao,
    budget: ref.watch(apiBudgetProvider),
    isOnline: () =>
        ref.read(serviceStatusProvider).value?.status == ServiceStatus.online,
  ),
);

/// Respaldo remoto de la búsqueda (una llamada, resultados a la base).
final remoteSearchProvider = Provider<RemoteSearch>(
  (ref) => RemoteSearch(
    remote: ref.watch(pokemonRemoteSourceProvider),
    local: CatalogLocalSource(ref.watch(appDatabaseProvider)),
  ),
);

/// Repositorio del catálogo: lo que la interfaz consume en lugar de GraphQL
/// o Drift. Las pruebas lo sobrescriben con uno falso.
final pokemonRepositoryProvider = Provider<PokemonRepository>(
  (ref) => PokemonRepositoryImpl(
    catalog: ref.watch(appDatabaseProvider).catalogDao,
    coordinator: ref.watch(syncCoordinatorProvider),
    sync: ref.watch(catalogSyncProvider),
    detail: ref.watch(detailSyncProvider),
    search: ref.watch(remoteSearchProvider),
    reference: ref.watch(appDatabaseProvider).referenceDao,
    preferences: ref.watch(appDatabaseProvider).preferenceDao,
  ),
);

/// Caso de uso: observar el catálogo.
final watchPokemonProvider = Provider<WatchPokemon>(
  (ref) => WatchPokemon(ref.watch(pokemonRepositoryProvider)),
);

/// Caso de uso: sincronizar el catálogo ahora.
final refreshCatalogProvider = Provider<RefreshCatalog>(
  (ref) => RefreshCatalog(ref.watch(pokemonRepositoryProvider)),
);

/// Caso de uso: buscar en PokéAPI cuando lo local no tiene resultados.
final searchPokemonRemoteProvider = Provider<SearchPokemonRemote>(
  (ref) => SearchPokemonRemote(ref.watch(pokemonRepositoryProvider)),
);

/// Caso de uso: traer el detalle de un Pokémon al abrirlo.
final syncPokemonDetailProvider = Provider<SyncPokemonDetail>(
  (ref) => SyncPokemonDetail(ref.watch(pokemonRepositoryProvider)),
);

final pokemonDetailRepositoryProvider = Provider<PokemonDetailRepository>(
  (ref) => PokemonDetailRepositoryImpl(
    catalog: ref.watch(appDatabaseProvider).catalogDao,
    reference: ref.watch(appDatabaseProvider).referenceDao,
  ),
);

final pokemonDetailProvider = StreamProvider.family<PokemonDetail?, int>(
  (ref, id) => ref.watch(pokemonDetailRepositoryProvider).watchDetail(id),
);

final pokemonEvolutionsProvider = StreamProvider.family<EvolutionChain?, int>(
  (ref, id) => ref.watch(pokemonDetailRepositoryProvider).watchEvolutions(id),
);

final typeChartProvider = StreamProvider<TypeChart>(
  (ref) => ref.watch(pokemonDetailRepositoryProvider).watchTypeChart(),
);

typedef MovesRequest = ({
  int pokemonId,
  MoveMethod method,
  int versionGroupId,
  int page,
});

/// Se vuelve a leer cuando termina la descarga del detalle.
final pokemonMoveGamesProvider = FutureProvider.family<MoveGames, int>((
  ref,
  pokemonId,
) {
  ref.watch(pokemonDetailRefreshProvider(pokemonId));
  return ref.watch(pokemonDetailRepositoryProvider).moveGames(pokemonId);
});

final pokemonMovesProvider = FutureProvider.family<MovePage, MovesRequest>(
  (ref, request) => ref
      .watch(pokemonDetailRepositoryProvider)
      .moves(
        request.pokemonId,
        request.method,
        versionGroupId: request.versionGroupId,
        page: request.page,
      ),
);

/// Descarga el detalle al abrir un Pokémon. Devuelve false si no se pudo: la
/// pantalla sigue con lo local. Si el detalle estaba vigente y no hubo
/// descarga, lo compara con el remoto sin esperar (OF-20); cuando sí se
/// descargó, esa comparación ya la hizo la descarga.
final pokemonDetailRefreshProvider = FutureProvider.family<bool, int>((
  ref,
  id,
) async {
  final wasFresh = await ref.read(detailSyncProvider).isFresh(id);
  try {
    await ref.watch(syncPokemonDetailProvider)(id);
  } on Failure {
    return false;
  }
  if (wasFresh && ref.mounted) {
    unawaited(ref.read(integrityCheckerProvider).verifyPokemon(id));
  }
  return true;
});
