import '../error/failure.dart';

/// Disponibilidad real de PokéAPI (ADR-007), no solo del Wi-Fi o los datos.
enum ServiceStatus {
  /// Aún no hay un estado estable (arranque).
  verificando,

  /// PokéAPI respondió.
  online,

  /// El dispositivo no tiene interfaz de red.
  offline,

  /// Hay red pero PokéAPI no responde (timeout, 5xx, 429 o error de esquema).
  servicioNoDisponible,
}

/// Tipo de interfaz de red activa.
enum NetworkKind { none, wifi, mobile, ethernet, other }

/// Estado del monitor en un instante, listo para el indicador global.
class ConnectivitySnapshot {
  const ConnectivitySnapshot({
    this.status = ServiceStatus.verificando,
    this.isVerifying = false,
    this.networkKind = NetworkKind.none,
    this.lastFailure,
    this.lastCheckAt,
    this.nextRetryAt,
  });

  /// Último estado estable: ya pasó la histéresis y no parpadea. Mientras se
  /// verifica conserva el valor anterior.
  final ServiceStatus status;

  /// Hay un health-check en curso.
  final bool isVerifying;

  final NetworkKind networkKind;

  /// Fallo que dejó el servicio sin responder; null si el último resultado fue bueno.
  final Failure? lastFailure;

  /// Instante del último resultado (health-check o consulta real).
  final DateTime? lastCheckAt;

  /// Instante del próximo reintento automático, si hay uno programado.
  final DateTime? nextRetryAt;

  @override
  bool operator ==(Object other) =>
      other is ConnectivitySnapshot &&
      other.status == status &&
      other.isVerifying == isVerifying &&
      other.networkKind == networkKind &&
      other.lastFailure == lastFailure &&
      other.lastCheckAt == lastCheckAt &&
      other.nextRetryAt == nextRetryAt;

  @override
  int get hashCode => Object.hash(
    status,
    isVerifying,
    networkKind,
    lastFailure,
    lastCheckAt,
    nextRetryAt,
  );

  @override
  String toString() =>
      'ConnectivitySnapshot($status, verificando: $isVerifying, red: $networkKind)';
}
