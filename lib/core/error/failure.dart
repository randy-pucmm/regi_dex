/// Fallos de dominio. La capa de datos traduce las excepciones de la red y de
/// GraphQL a estos tipos, y nada de la infraestructura sale de esa capa.
sealed class Failure implements Exception {
  const Failure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Sin conexión: el dispositivo no pudo abrir la conexión con el servidor.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sin conexión con el servidor']);
}

/// La respuesta no llegó dentro del tiempo permitido.
final class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'El servidor no respondió a tiempo']);
}

/// Error de GraphQL sin datos. [isValidation] es true cuando el servidor
/// rechazó la consulta por inválida: reintentarla no sirve.
final class GraphQLFailure extends Failure {
  const GraphQLFailure(super.message, {this.isValidation = false});

  final bool isValidation;
}

/// La respuesta trae datos y errores a la vez; [data] conserva lo recibido.
final class PartialDataFailure extends Failure {
  const PartialDataFailure(super.message, {required this.data});

  final Map<String, dynamic> data;
}

/// Límite de llamadas superado (HTTP 429). [retryAfter] es la espera mínima.
final class RateLimitFailure extends Failure {
  const RateLimitFailure(super.message, {required this.retryAfter});

  final Duration retryAfter;
}

/// El servidor falló o no es utilizable (HTTP 5xx, endpoint inexistente,
/// respuesta ilegible). [statusCode] es el estado HTTP, si se conoce.
final class ServiceUnavailableFailure extends Failure {
  const ServiceUnavailableFailure(super.message, {this.statusCode});

  final int? statusCode;
}

/// Un DTO no cumple el contrato esperado; el lote se descarta sin tocar la BD.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
