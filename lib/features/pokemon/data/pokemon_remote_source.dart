import '../../../core/network/graphql_operation.dart';
import '../../../core/network/poke_api_client.dart';
import '../../../core/sync/api_budget.dart';

/// Llamadas a PokéAPI del catálogo. Cada una gasta una unidad del presupuesto
/// (`ApiBudget.guard`) y devuelve el `data` crudo; el DTO y el mapeo ocurren
/// después, fuera del hilo principal.
class PokemonRemoteSource {
  PokemonRemoteSource({required this._client, required this._budget});

  final PokeApiClient _client;
  final ApiBudget _budget;

  /// Idiomas pedidos en los datos de referencia.
  static const languages = ['es', 'en'];

  /// GetReferenceData: tipos, generaciones, grupos huevo, habilidades,
  /// movimientos y eficacias en una sola llamada.
  Future<Map<String, dynamic>> fetchReference() =>
      _call(GraphqlOperation.getReferenceData, {'langs': languages});

  /// GetPokemonPage: [limit] Pokémon por defecto ordenados por id desde
  /// [offset]. Entrega la lista `pokemon` dentro del `data`.
  Future<Map<String, dynamic>> fetchPage({
    required int offset,
    required int limit,
  }) => _call(GraphqlOperation.getPokemonPage, {
    'limit': limit,
    'offset': offset,
  });

  Future<Map<String, dynamic>> _call(
    GraphqlOperation operation,
    Map<String, dynamic> variables,
  ) => _budget.guard(
    operation.operationName,
    () => _client.execute(operation, variables: variables),
  );
}
