import 'dart:async';

import 'sync_status.dart';

/// Coordina las sincronizaciones por recurso (RNF-RES-03): una sola ejecución
/// a la vez por `resourceKey` (single-flight) y un estado global observable.
///
/// Uso: `await coordinator.run('catalog', () => ...)`. Una segunda solicitud
/// del mismo recurso mientras corre la primera recibe el mismo `Future`.
class SyncCoordinator {
  final _inFlight = <String, Future<dynamic>>{};
  final _controller = StreamController<SyncStatus>.broadcast();
  var _running = 0;
  var _status = SyncStatus.inactiva;
  var _disposed = false;

  /// Estado actual.
  SyncStatus get status => _status;

  /// Estados de la sincronización: emite el actual al suscribirse y luego
  /// cada cambio.
  Stream<SyncStatus> get statuses {
    late final StreamController<SyncStatus> controller;
    StreamSubscription<SyncStatus>? subscription;
    controller = StreamController<SyncStatus>(
      onListen: () {
        controller.add(_status);
        subscription = _controller.stream.listen(
          controller.add,
          onDone: controller.close,
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  /// Indica si [resourceKey] se está sincronizando.
  bool isRunning(String resourceKey) => _inFlight.containsKey(resourceKey);

  /// Ejecuta [action] para [resourceKey] y devuelve su resultado. Si ya hay
  /// una ejecución en curso de ese recurso, devuelve esa misma. Las solicitudes
  /// simultáneas de una misma clave deben usar el mismo tipo de resultado.
  Future<T> run<T>(String resourceKey, Future<T> Function() action) {
    final existing = _inFlight[resourceKey];
    if (existing != null) return existing as Future<T>;

    final future = _execute(action).whenComplete(() {
      // Con bloque: devolver el resultado de `remove` haría que el Future
      // esperara a sí mismo.
      _inFlight.remove(resourceKey);
    });
    _inFlight[resourceKey] = future;
    return future;
  }

  /// Cierra el flujo de estados.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_controller.close());
  }

  Future<T> _execute<T>(Future<T> Function() action) async {
    _running++;
    _setStatus(SyncStatus.sincronizando);
    try {
      final result = await action();
      _finish(SyncStatus.completada);
      return result;
    } catch (_) {
      _finish(SyncStatus.fallida);
      rethrow;
    }
  }

  /// Registra el fin de una ejecución; el estado terminal solo se publica
  /// cuando ya no queda ninguna en curso.
  void _finish(SyncStatus terminal) {
    _running--;
    if (_running == 0) _setStatus(terminal);
  }

  void _setStatus(SyncStatus status) {
    if (_disposed || status == _status) return;
    _status = status;
    _controller.add(status);
  }
}
