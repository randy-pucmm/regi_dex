import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql/client.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/network/failure_mapper.dart';

QueryResult _result({
  OperationException? exception,
  Map<String, dynamic>? data,
}) => QueryResult(
  options: QueryOptions(document: gql('query A { a }')),
  source: QueryResultSource.network,
  exception: exception,
  data: data,
);

OperationException _link(LinkException exception) =>
    OperationException(linkException: exception);

void main() {
  test('un resultado sin excepción no es un fallo', () {
    expect(failureFromResult(_result(data: {'a': 1})), isNull);
    expect(httpStatusOf(_result(data: {'a': 1})), isNull);
  });

  test('UnknownException con TimeoutException → TimeoutFailure', () {
    final failure = failureFromResult(
      _result(
        exception: _link(
          UnknownException(TimeoutException('lento'), StackTrace.empty),
        ),
      ),
    );
    expect(failure, isA<TimeoutFailure>());
  });

  test('NetworkException → NetworkFailure', () {
    final failure = failureFromResult(
      _result(
        exception: _link(
          NetworkException(
            originalException: const SocketException('sin red'),
            uri: Uri.parse('https://example.test'),
          ),
        ),
      ),
    );
    expect(failure, isA<NetworkFailure>());
  });

  test('ServerException con SocketException → NetworkFailure', () {
    final failure = failureFromResult(
      _result(
        exception: _link(
          const ServerException(originalException: SocketException('sin red')),
        ),
      ),
    );
    expect(failure, isA<NetworkFailure>());
  });

  test('ServerException con un fallo TLS → ServiceUnavailableFailure', () {
    final failure = failureFromResult(
      _result(
        exception: _link(
          const ServerException(
            originalException: HandshakeException('certificado'),
          ),
        ),
      ),
    );
    expect(failure, isA<ServiceUnavailableFailure>());
  });

  test('ServerException con estado HTTP expone ese estado', () {
    final result = _result(
      exception: _link(const ServerException(statusCode: 502)),
    );
    expect(httpStatusOf(result), 502);
  });

  test('errores GraphQL sin datos → GraphQLFailure con sus mensajes', () {
    final failure = failureFromResult(
      _result(
        exception: OperationException(
          graphqlErrors: const [
            GraphQLError(message: 'uno'),
            GraphQLError(message: 'dos'),
          ],
        ),
      ),
    );
    expect(failure, isA<GraphQLFailure>());
    expect(failure!.message, 'uno; dos');
  });

  test('errores GraphQL con datos → PartialDataFailure', () {
    final failure = failureFromResult(
      _result(
        data: {'a': 1},
        exception: OperationException(
          graphqlErrors: const [GraphQLError(message: 'parcial')],
        ),
      ),
    );
    expect(failure, isA<PartialDataFailure>());
    expect((failure! as PartialDataFailure).data, {'a': 1});
  });

  test('failureFromError traduce los errores de transporte', () {
    expect(failureFromError(TimeoutException('x')), isA<TimeoutFailure>());
    expect(failureFromError(const SocketException('x')), isA<NetworkFailure>());
    expect(failureFromError(const HttpException('x')), isA<NetworkFailure>());
    expect(failureFromError(StateError('x')), isA<ServiceUnavailableFailure>());
    const failure = ValidationFailure('x');
    expect(failureFromError(failure), same(failure));
  });
}
