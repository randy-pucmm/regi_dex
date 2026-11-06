import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:graphql/client.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../error/failure.dart';
import 'failure_mapper.dart';
import 'graphql_operation.dart';
import 'operation_loader.dart';
import 'poke_api_config.dart';

/// Resultado de una llamada a PokéAPI, publicado en [PokeApiClient.calls].
class ApiCallEvent {
  const ApiCallEvent({
    required this.operation,
    required this.duration,
    required this.attempt,
    this.httpStatus,
    this.failure,
  });

  final GraphqlOperation operation;
  final Duration duration;
  final int attempt;
  final int? httpStatus;

  /// Null cuando la llamada tuvo éxito.
  final Failure? failure;

  bool get isSuccess => failure == null;
}

/// Cliente GraphQL de PokéAPI: sin caché (la fuente de verdad es Drift),
/// con timeouts explícitos y errores traducidos a [Failure].
class PokeApiClient {
  /// [endpoint] es la URL GraphQL; [loader] entrega los documentos `.graphql`.
  /// [httpClient] sustituye al cliente HTTP (pruebas). [log] recibe una línea
  /// por operación (por defecto, la consola).
  PokeApiClient({
    required Uri endpoint,
    required this._loader,
    http.Client? httpClient,
    Duration connectTimeout = defaultConnectTimeout,
    this.responseTimeout = defaultResponseTimeout,
    void Function(String message)? log,
  }) : _log = log ?? debugPrint {
    _link = HttpLink(
      endpoint.toString(),
      httpClient:
          httpClient ??
          IOClient(HttpClient()..connectionTimeout = connectTimeout),
    );
    _client = GraphQLClient(
      link: _link,
      cache: GraphQLCache(),
      defaultPolicies: DefaultPolicies(
        query: Policies(
          fetch: FetchPolicy.noCache,
          error: ErrorPolicy.all,
          cacheReread: CacheRereadPolicy.ignoreAll,
        ),
      ),
    );
  }

  final Duration responseTimeout;
  final OperationLoader _loader;
  final void Function(String message) _log;
  final _calls = StreamController<ApiCallEvent>.broadcast();
  late final HttpLink _link;
  late final GraphQLClient _client;

  /// Un evento por cada llamada terminada, con éxito o con fallo.
  Stream<ApiCallEvent> get calls => _calls.stream;

  /// Ejecuta [operation] con [variables] y devuelve el `data` de la respuesta.
  /// [timeout] sustituye al de respuesta y [attempt] solo identifica el
  /// intento en el registro. Lanza un [Failure] si la llamada falla.
  Future<Map<String, dynamic>> execute(
    GraphqlOperation operation, {
    Map<String, dynamic> variables = const {},
    Duration? timeout,
    int attempt = 1,
  }) async {
    final document = gql(await _loader.load(operation));
    final stopwatch = Stopwatch()..start();
    Map<String, dynamic>? data;
    Failure? failure;
    int? httpStatus;

    try {
      final result = await _client
          .query(
            QueryOptions(
              document: document,
              operationName: operation.operationName,
              variables: variables,
            ),
          )
          .timeout(timeout ?? responseTimeout);
      httpStatus = httpStatusOf(result);
      failure = failureFromResult(result);
      data = result.data;
    } on TimeoutException catch (error) {
      failure = failureFromError(error);
    }

    stopwatch.stop();
    final event = ApiCallEvent(
      operation: operation,
      duration: stopwatch.elapsed,
      attempt: attempt,
      httpStatus: httpStatus,
      failure: failure,
    );
    _log(_describe(event));
    if (!_calls.isClosed) _calls.add(event);

    if (failure != null) throw failure;
    return data!;
  }

  /// Libera el cliente HTTP y cierra el flujo de [calls].
  void dispose() {
    _link.dispose();
    _calls.close();
  }

  String _describe(ApiCallEvent event) {
    final status = event.httpStatus == null ? '' : ', HTTP ${event.httpStatus}';
    final outcome = event.isSuccess ? 'ok' : 'falló (${event.failure})';
    return '[GraphQL] ${event.operation.operationName} $outcome '
        'en ${event.duration.inMilliseconds} ms '
        '(intento ${event.attempt}$status)';
  }
}
