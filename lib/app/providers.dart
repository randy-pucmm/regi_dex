import 'package:flutter_riverpod/flutter_riverpod.dart';

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
