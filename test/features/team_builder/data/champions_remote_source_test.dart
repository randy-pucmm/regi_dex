import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/features/team_builder/data/champions_remote_source.dart';

void main() {
  late List<Uri> requests;
  late List<String> logs;

  ChampionsRemoteSource sourceFor(
    Future<http.Response> Function(http.Request) handler, {
    String endpoint = 'https://champions.test',
  }) {
    requests = [];
    logs = [];
    return ChampionsRemoteSource(
      endpoint: Uri.parse(endpoint),
      client: MockClient((request) {
        requests.add(request.url);
        return handler(request);
      }),
      log: logs.add,
    );
  }

  test('fetchIndex pide GET /api y devuelve el cuerpo', () async {
    final source = sourceFor((_) async => http.Response('{"a":1}', 200));

    final body = await source.fetchIndex();

    expect(String.fromCharCodes(body), '{"a":1}');
    expect(requests.single.toString(), 'https://champions.test/api');
    expect(logs.single, contains('GET /api ok'));
  });

  test('un 429 es RateLimitFailure con al menos 60 s de espera', () async {
    final source = sourceFor(
      (_) async => http.Response('', 429, headers: {'retry-after': '5'}),
    );

    await expectLater(
      source.fetchIndex(),
      throwsA(
        isA<RateLimitFailure>().having(
          (f) => f.retryAfter,
          'retryAfter',
          const Duration(seconds: 60),
        ),
      ),
    );
  });

  test('un 429 respeta un Retry-After mayor al mínimo', () async {
    final source = sourceFor(
      (_) async => http.Response('', 429, headers: {'retry-after': '300'}),
    );

    await expectLater(
      source.fetchIndex(),
      throwsA(
        isA<RateLimitFailure>().having(
          (f) => f.retryAfter,
          'retryAfter',
          const Duration(seconds: 300),
        ),
      ),
    );
  });

  test('un 503 es ServiceUnavailableFailure con su estado', () async {
    final source = sourceFor((_) async => http.Response('', 503));

    await expectLater(
      source.fetchIndex(),
      throwsA(
        isA<ServiceUnavailableFailure>().having(
          (f) => f.statusCode,
          'statusCode',
          503,
        ),
      ),
    );
    expect(logs.single, contains('falló'));
  });

  test('un 404 también es ServiceUnavailableFailure', () async {
    final source = sourceFor((_) async => http.Response('no', 404));

    await expectLater(
      source.fetchIndex(),
      throwsA(isA<ServiceUnavailableFailure>()),
    );
  });

  test('sin conexión es NetworkFailure', () async {
    final source = sourceFor(
      (_) async => throw const SocketException('sin red'),
    );

    await expectLater(source.fetchIndex(), throwsA(isA<NetworkFailure>()));
  });

  test('pasados 20 s sin respuesta es TimeoutFailure', () {
    fakeAsync((async) {
      final source = sourceFor((_) => Completer<http.Response>().future);
      Object? error;
      source.fetchIndex().then<void>((_) {}, onError: (Object e) => error = e);

      async.elapse(const Duration(seconds: 19));
      expect(error, isNull);
      async.elapse(const Duration(seconds: 2));
      expect(error, isA<TimeoutFailure>());
    });
  });

  test('baseUrl devuelve la raíz configurada', () {
    final source = sourceFor((_) async => http.Response('', 200));
    expect(source.baseUrl, 'https://champions.test');
  });
}
