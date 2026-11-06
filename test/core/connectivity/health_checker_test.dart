import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:regi_dex/core/connectivity/health_checker.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/network/operation_loader.dart';
import 'package:regi_dex/core/network/poke_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> logs;
  late List<String> bodies;
  late PokeApiClient client;

  /// Crea el cliente con un servidor que responde [status] y [body].
  GraphqlHealthChecker checkerFor(Object body, {int status = 200}) {
    client = PokeApiClient(
      endpoint: Uri.parse('https://example.test/graphql'),
      loader: OperationLoader(),
      httpClient: MockClient((request) async {
        bodies.add(request.body);
        return http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
      log: logs.add,
    );
    return GraphqlHealthChecker(client);
  }

  setUp(() {
    logs = [];
    bodies = [];
  });
  tearDown(() => client.dispose());

  test('responde bien con un Pokémon', () async {
    final checker = checkerFor({
      'data': {
        'pokemon': [
          {'id': 1},
        ],
      },
    });

    await expectLater(checker.check(), completes);

    expect(jsonDecode(bodies.single)['operationName'], 'HealthCheck');
  });

  test('una lista vacía significa que la base no contesta', () async {
    final checker = checkerFor({
      'data': {'pokemon': <dynamic>[]},
    });

    await expectLater(
      checker.check(),
      throwsA(isA<ServiceUnavailableFailure>()),
    );
  });

  test('propaga el fallo de la llamada', () async {
    final checker = checkerFor({'errors': <dynamic>[]}, status: 503);

    await expectLater(
      checker.check(),
      throwsA(isA<ServiceUnavailableFailure>()),
    );
  });

  test('el número de intento llega al registro de consola', () async {
    final checker = checkerFor({
      'data': {
        'pokemon': [
          {'id': 1},
        ],
      },
    });

    await checker.check(attempt: 3);

    expect(logs.single, contains('HealthCheck ok'));
    expect(logs.single, contains('intento 3'));
  });
}
