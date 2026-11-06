import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connectivity/connectivity_monitor.dart';
import '../core/connectivity/health_checker.dart';
import '../core/connectivity/network_source.dart';
import '../core/connectivity/service_status.dart';
import '../core/database/app_database.dart';
import '../core/network/operation_loader.dart';
import '../core/network/poke_api_client.dart';
import '../core/network/poke_api_config.dart';

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

/// Health-check contra PokéAPI.
final healthCheckerProvider = Provider<HealthChecker>(
  (ref) => GraphqlHealthChecker(ref.watch(pokeApiClientProvider)),
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
