import 'dart:async';
import 'dart:io';

import 'package:graphql/client.dart';
import 'package:http/http.dart' as http;

import '../error/failure.dart';

/// Espera mínima ante un 429, aunque `Retry-After` indique menos o falte.
const minRateLimitWait = Duration(seconds: 60);

/// Códigos de error de Hasura que indican una consulta inválida (no reintentar).
const _validationCodes = {'validation-failed', 'parse-failed', 'bad-request'};

/// Traduce el resultado de una operación a un [Failure] según la tabla 6.3 de
/// la arquitectura. Devuelve null si [result] no trae ningún error.
Failure? failureFromResult(QueryResult result) {
  final exception = result.exception;
  if (exception == null) return null;

  final link = exception.linkException;
  if (link != null) return _fromLinkException(link);

  final errors = exception.graphqlErrors;
  final data = result.data;
  if (data != null && data.isNotEmpty) {
    return PartialDataFailure(_describe(errors), data: data);
  }
  return GraphQLFailure(
    _describe(errors),
    isValidation: errors.any(_isValidation),
  );
}

/// Traduce una excepción de transporte (por ejemplo, un `TimeoutException`).
Failure failureFromError(Object? error) {
  return switch (error) {
    Failure() => error,
    TimeoutException() => const TimeoutFailure(),
    SocketException() ||
    http.ClientException() ||
    HttpException() => NetworkFailure('Sin conexión con el servidor: $error'),
    _ => ServiceUnavailableFailure('Fallo de transporte: $error'),
  };
}

/// Estado HTTP de la respuesta de [result], o null si no se conoce.
int? httpStatusOf(QueryResult result) {
  final status = result.context.entry<HttpLinkResponseContext>()?.statusCode;
  if (status != null) return status;
  return switch (result.exception?.linkException) {
    HttpLinkServerException(:final response) => response.statusCode,
    HttpLinkParserException(:final response) => response.statusCode,
    ServerException(:final statusCode) => statusCode,
    _ => null,
  };
}

Failure _fromLinkException(LinkException exception) {
  return switch (exception) {
    HttpLinkServerException(:final response, :final parsedResponse) =>
      _fromHttpStatus(
        response.statusCode,
        response.headers,
        errors: parsedResponse?.errors,
      ),
    HttpLinkParserException(:final response) => _fromHttpStatus(
      response.statusCode,
      response.headers,
    ),
    NetworkException() => NetworkFailure(exception.toString()),
    ServerException(:final originalException) => failureFromError(
      originalException,
    ),
    UnknownException(:final originalException) => failureFromError(
      originalException,
    ),
    _ => ServiceUnavailableFailure('Fallo del enlace GraphQL: $exception'),
  };
}

/// Un estado HTTP >= 300 (o una respuesta ilegible con 2xx) sin errores
/// GraphQL propios significa que el servicio no es utilizable; el 429 es
/// el límite de llamadas.
Failure _fromHttpStatus(
  int status,
  Map<String, String> headers, {
  List<GraphQLError>? errors,
}) {
  if (status == 429) {
    return RateLimitFailure(
      'PokéAPI limitó las llamadas (HTTP 429)',
      retryAfter: _retryAfter(headers),
    );
  }
  final isClientError = status >= 400 && status < 500;
  if (isClientError && errors != null && errors.isNotEmpty) {
    return GraphQLFailure(
      _describe(errors),
      isValidation: errors.any(_isValidation),
    );
  }
  final message = status < 300
      ? 'Respuesta de PokéAPI ilegible o vacía (HTTP $status)'
      : 'PokéAPI respondió HTTP $status';
  return ServiceUnavailableFailure(message, statusCode: status);
}

/// Lee `Retry-After` en segundos y lo lleva al mínimo de [minRateLimitWait].
Duration _retryAfter(Map<String, String> headers) {
  final seconds = int.tryParse(headers['retry-after'] ?? '');
  final wait = Duration(seconds: seconds ?? 0);
  return wait < minRateLimitWait ? minRateLimitWait : wait;
}

bool _isValidation(GraphQLError error) =>
    _validationCodes.contains(error.extensions?['code']);

String _describe(List<GraphQLError> errors) => errors.isEmpty
    ? 'Error de GraphQL'
    : errors.map((e) => e.message).join('; ');
