import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/network/graphql_operation.dart';
import 'package:regi_dex/core/network/operation_loader.dart';
import 'package:regi_dex/core/network/poke_api_client.dart';

final _endpoint = Uri.parse('https://example.test/graphql');

http.Response _json(
  Object body, {
  int status = 200,
  Map<String, String> headers = const {},
}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json', ...headers},
);

http.Response _html(int status) => http.Response(
  '<html>error</html>',
  status,
  headers: {'content-type': 'text/html'},
);

const _healthData = {
  'data': {
    'pokemon': [
      {'id': 1},
    ],
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> logs;
  late PokeApiClient client;

  /// Crea el cliente con [handler] como servidor.
  void serve(
    Future<http.Response> Function(http.Request request) handler, {
    Duration responseTimeout = const Duration(seconds: 2),
  }) {
    client = PokeApiClient(
      endpoint: _endpoint,
      loader: OperationLoader(),
      httpClient: MockClient(handler),
      responseTimeout: responseTimeout,
      log: logs.add,
    );
  }

  setUp(() => logs = []);
  tearDown(() => client.dispose());

  Future<Map<String, dynamic>> health() =>
      client.execute(GraphqlOperation.healthCheck);

  group('llamada correcta', () {
    test('devuelve el data y registra la operación en consola', () async {
      serve((_) async => _json(_healthData));

      final data = await health();

      expect(data['pokemon'], [
        {'id': 1},
      ]);
      expect(logs, hasLength(1));
      expect(logs.single, contains('[GraphQL] HealthCheck ok'));
      expect(logs.single, contains('intento 1'));
      expect(logs.single, contains('HTTP 200'));
    });

    test(
      'envía un POST JSON al endpoint con la operación y sus variables',
      () async {
        late http.Request seen;
        serve((request) async {
          seen = request;
          return _json({
            'data': {'pokemon': []},
          });
        });

        await client.execute(
          GraphqlOperation.getPokemonPage,
          variables: {'limit': 200, 'offset': 400},
        );

        expect(seen.method, 'POST');
        expect(seen.url, _endpoint);
        expect(seen.headers['Content-type'], contains('application/json'));
        final body = jsonDecode(seen.body) as Map<String, dynamic>;
        expect(body['operationName'], 'GetPokemonPage');
        expect(body['variables'], {'limit': 200, 'offset': 400});
        expect(body['query'], contains('fragment PokemonLight'));
      },
    );

    test('no usa caché: cada llamada va a la red (noCache)', () async {
      var calls = 0;
      serve((_) async {
        calls++;
        return _json(_healthData);
      });

      await health();
      await health();

      expect(calls, 2);
    });
  });

  group('errores del servidor', () {
    test('errores GraphQL sin datos → GraphQLFailure', () async {
      serve(
        (_) async => _json({
          'errors': [
            {'message': 'campo inexistente'},
          ],
        }),
      );

      await expectLater(
        health(),
        throwsA(
          isA<GraphQLFailure>()
              .having((f) => f.isValidation, 'isValidation', isFalse)
              .having(
                (f) => f.message,
                'message',
                contains('campo inexistente'),
              ),
        ),
      );
    });

    test(
      'error de validación de Hasura → GraphQLFailure con isValidation',
      () async {
        serve(
          (_) async => _json({
            'errors': [
              {
                'message': 'field not found',
                'extensions': {'code': 'validation-failed'},
              },
            ],
          }),
        );

        await expectLater(
          health(),
          throwsA(
            isA<GraphQLFailure>().having(
              (f) => f.isValidation,
              'isValidation',
              isTrue,
            ),
          ),
        );
      },
    );

    test('datos con errores → PartialDataFailure con lo recibido', () async {
      serve(
        (_) async => _json({
          'data': {
            'pokemon': [
              {'id': 1},
            ],
          },
          'errors': [
            {'message': 'un campo falló'},
          ],
        }),
      );

      await expectLater(
        health(),
        throwsA(
          isA<PartialDataFailure>().having((f) => f.data['pokemon'], 'data', [
            {'id': 1},
          ]),
        ),
      );
    });

    test(
      'HTTP 400 con error de validación → GraphQLFailure con isValidation',
      () async {
        serve(
          (_) async => _json({
            'errors': [
              {
                'message': 'bad query',
                'extensions': {'code': 'parse-failed'},
              },
            ],
          }, status: 400),
        );

        await expectLater(
          health(),
          throwsA(
            isA<GraphQLFailure>().having(
              (f) => f.isValidation,
              'isValidation',
              isTrue,
            ),
          ),
        );
      },
    );
  });

  group('límite de llamadas (429)', () {
    Matcher rateLimitOf(Duration wait) =>
        isA<RateLimitFailure>().having((f) => f.retryAfter, 'retryAfter', wait);

    test('respeta Retry-After cuando supera el mínimo', () async {
      serve(
        (_) async => _json({}, status: 429, headers: {'retry-after': '120'}),
      );
      await expectLater(
        health(),
        throwsA(rateLimitOf(const Duration(seconds: 120))),
      );
    });

    test('sube a 60 s si Retry-After es menor', () async {
      serve(
        (_) async => _json({}, status: 429, headers: {'retry-after': '10'}),
      );
      await expectLater(
        health(),
        throwsA(rateLimitOf(const Duration(seconds: 60))),
      );
    });

    test('usa 60 s si no hay Retry-After', () async {
      serve((_) async => _html(429));
      await expectLater(
        health(),
        throwsA(rateLimitOf(const Duration(seconds: 60))),
      );
    });
  });

  group('servicio no disponible', () {
    Matcher unavailable(int? status) => isA<ServiceUnavailableFailure>().having(
      (f) => f.statusCode,
      'statusCode',
      status,
    );

    test('HTTP 5xx con HTML', () async {
      serve((_) async => _html(503));
      await expectLater(health(), throwsA(unavailable(503)));
    });

    test('HTTP 5xx con cuerpo JSON', () async {
      serve(
        (_) async => _json({
          'errors': [
            {'message': 'internal'},
          ],
        }, status: 500),
      );
      await expectLater(health(), throwsA(unavailable(500)));
    });

    test('endpoint inexistente (simulador de API caída, PA-08)', () async {
      serve((_) async => _html(404));
      await expectLater(health(), throwsA(unavailable(404)));
    });

    test('cuerpo que no es JSON con HTTP 200', () async {
      serve((_) async => http.Response('no es json', 200));
      await expectLater(health(), throwsA(unavailable(200)));
    });

    test('respuesta sin data ni errors', () async {
      serve((_) async => _json({}));
      await expectLater(health(), throwsA(unavailable(200)));
    });
  });

  group('red y tiempo', () {
    test('SocketException → NetworkFailure', () async {
      serve((_) async => throw const SocketException('Failed host lookup'));
      await expectLater(health(), throwsA(isA<NetworkFailure>()));
    });

    test('ClientException → NetworkFailure', () async {
      serve((_) async => throw http.ClientException('Connection reset'));
      await expectLater(health(), throwsA(isA<NetworkFailure>()));
    });

    test('sin respuesta dentro del timeout → TimeoutFailure', () async {
      serve(
        (_) => Completer<http.Response>().future,
        responseTimeout: const Duration(milliseconds: 50),
      );
      await expectLater(health(), throwsA(isA<TimeoutFailure>()));
    });

    test('el timeout de la llamada sustituye al del cliente', () async {
      serve((_) => Completer<http.Response>().future);
      await expectLater(
        client.execute(
          GraphqlOperation.healthCheck,
          timeout: const Duration(milliseconds: 30),
        ),
        throwsA(isA<TimeoutFailure>()),
      );
    });
  });

  group('flujo de llamadas', () {
    test('emite un evento por llamada, con éxito o con fallo', () async {
      var fail = false;
      serve((_) async => fail ? _html(503) : _json(_healthData));

      final events = <ApiCallEvent>[];
      final subscription = client.calls.listen(events.add);

      await health();
      fail = true;
      await expectLater(
        client.execute(GraphqlOperation.healthCheck, attempt: 2),
        throwsA(isA<Failure>()),
      );
      await pumpEventQueue();
      await subscription.cancel();

      expect(events, hasLength(2));
      expect(events[0].isSuccess, isTrue);
      expect(events[0].operation, GraphqlOperation.healthCheck);
      expect(events[0].httpStatus, 200);
      expect(events[1].isSuccess, isFalse);
      expect(events[1].failure, isA<ServiceUnavailableFailure>());
      expect(events[1].attempt, 2);
      expect(events[1].httpStatus, 503);
      expect(logs[1], contains('falló'));
    });
  });
}
