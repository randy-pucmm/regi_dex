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

  /// Máximo de resultados de una búsqueda remota.
  static const searchLimit = 20;

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

  /// SearchPokemonRemote: hasta [limit] Pokémon por defecto cuyo nombre contiene
  /// [name] o cuyo número nacional es [number]; se da uno solo de los dos.
  /// Entrega la lista `pokemon` dentro del `data`.
  Future<Map<String, dynamic>> searchPokemon({
    String? name,
    int? number,
    int limit = searchLimit,
  }) => _call(GraphqlOperation.searchPokemonRemote, {
    'pattern': name == null ? '' : '%${_escapeLike(name)}%',
    'id': number ?? 0,
    'limit': limit,
  });

  /// GetPokemonDetail: el detalle completo de [id], con su cadena evolutiva,
  /// en una sola llamada. Entrega la lista `pokemon` (0 o 1 elemento).
  Future<Map<String, dynamic>> fetchDetail(int id) =>
      _call(GraphqlOperation.getPokemonDetail, {'id': id, 'langs': languages});

  Future<Map<String, dynamic>> _call(
    GraphqlOperation operation,
    Map<String, dynamic> variables,
  ) => _budget.guard(
    operation.operationName,
    () => _client.execute(operation, variables: variables),
  );
}

/// Escapa `\`, `%` y `_` para que `_ilike` los trate como texto literal.
String _escapeLike(String text) =>
    text.replaceAllMapped(RegExp(r'[\\%_]'), (match) => '\\${match[0]}');
