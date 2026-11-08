import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connectivity/budgeted_health_checker.dart';
import '../core/connectivity/connectivity_monitor.dart';
import '../core/connectivity/health_checker.dart';
import '../core/connectivity/network_source.dart';
import '../core/connectivity/service_status.dart';
import '../core/database/app_database.dart';
import '../core/network/operation_loader.dart';
import '../core/network/poke_api_client.dart';
import '../core/network/poke_api_config.dart';
import '../core/sync/api_budget.dart';
import '../core/sync/sync_coordinator.dart';
import '../core/sync/sync_status.dart';
import '../features/pokemon/data/catalog_local_source.dart';
import '../features/pokemon/data/catalog_sync.dart';
import '../features/pokemon/data/pokemon_remote_source.dart';
import '../features/pokemon/data/pokemon_repository_impl.dart';
import '../features/pokemon/domain/pokemon_repository.dart';
import '../features/pokemon/domain/refresh_catalog.dart';
import '../features/pokemon/domain/watch_pokemon.dart';

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

/// Repositorio del catálogo: lo que la interfaz consume en lugar de GraphQL
/// o Drift. Las pruebas lo sobrescriben con uno falso.
final pokemonRepositoryProvider = Provider<PokemonRepository>(
  (ref) => PokemonRepositoryImpl(
    catalog: ref.watch(appDatabaseProvider).catalogDao,
    coordinator: ref.watch(syncCoordinatorProvider),
    sync: ref.watch(catalogSyncProvider),
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
