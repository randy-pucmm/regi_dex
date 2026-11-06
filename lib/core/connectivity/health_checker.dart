import '../error/failure.dart';
import '../network/graphql_operation.dart';
import '../network/poke_api_client.dart';
import '../network/poke_api_config.dart';

/// Confirma que PokéAPI responde de verdad (OF-11).
abstract interface class HealthChecker {
  /// Termina sin error si el servicio respondió; si no, lanza un [Failure].
  Future<void> check();
}

/// Health-check con la consulta `HealthCheck` (un id, 31 bytes) y un timeout
/// de 5 s.
class GraphqlHealthChecker implements HealthChecker {
  GraphqlHealthChecker(this._client);

  final PokeApiClient _client;

  @override
  Future<void> check() async {
    final data = await _client.execute(
      GraphqlOperation.healthCheck,
      timeout: healthCheckTimeout,
    );
    final pokemon = data['pokemon'];
    if (pokemon is! List || pokemon.isEmpty) {
      throw const ServiceUnavailableFailure(
        'HealthCheck respondió sin datos: la base de PokéAPI no contesta',
      );
    }
  }
}
