import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/network/graphql_operation.dart';

/// Pruebas con un servidor local real: ejercitan el cliente HTTP que construye
/// el provider.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer server;
  late List<String> paths;

  setUp(() async {
    // El binding de pruebas bloquea la red; estas pruebas hablan con localhost.
    HttpOverrides.global = null;
    paths = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      paths.add(request.uri.path);
      await utf8.decoder.bind(request).join();
      if (request.uri.path == '/__regidex_down__') {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': {
              'pokemon': [
                {'id': 1},
              ],
            },
          }),
        );
      }
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  ProviderContainer containerFor(String path) {
    final container = ProviderContainer(
      overrides: [
        pokeApiEndpointProvider.overrideWithValue(
          Uri.parse('http://127.0.0.1:${server.port}$path'),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('el endpoint por defecto es el GraphQL de PokéAPI', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(pokeApiEndpointProvider).toString(),
      'https://graphql.pokeapi.co/v1beta2',
    );
  });

  test('sobrescribir el endpoint dirige las llamadas a la nueva URL', () async {
    final client = containerFor('/graphql').read(pokeApiClientProvider);

    final data = await client.execute(GraphqlOperation.healthCheck);

    expect(paths, ['/graphql']);
    expect(data['pokemon'], isNotEmpty);
  });

  test(
    'el endpoint de API caída (PA-08) da ServiceUnavailableFailure',
    () async {
      final client = containerFor('/__regidex_down__')
          .read(pokeApiClientProvider);

      await expectLater(
        client.execute(GraphqlOperation.healthCheck),
        throwsA(
          isA<ServiceUnavailableFailure>().having(
            (f) => f.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    },
  );

  test('un servidor que no escucha da NetworkFailure', () async {
    final container = containerFor('/graphql');
    await server.close(force: true);

    await expectLater(
      container
          .read(pokeApiClientProvider)
          .execute(GraphqlOperation.healthCheck),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
