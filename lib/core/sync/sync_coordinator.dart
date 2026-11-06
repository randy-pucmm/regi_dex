import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;

import '../database/app_database.dart';
import '../database/daos/sync_metadata_dao.dart';
import '../error/failure.dart';
import 'backoff_policy.dart';
import 'sync_status.dart';

/// Valores de `sync_metadata.status`.
abstract final class SyncMetadataStatus {
  static const syncing = 'syncing';
  static const completed = 'completed';
  static const failed = 'failed';
}

/// Coordina las sincronizaciones por recurso (RNF-RES-03): una sola ejecución
/// a la vez por `resourceKey` (single-flight), el registro del avance en
/// `sync_metadata` (PS-09) y un estado global observable.
///
/// Uso: `await coordinator.run('catalog', () => ...)`. Una segunda solicitud
/// del mismo recurso mientras corre la primera recibe el mismo `Future`. Los
/// reintentos automáticos no están aquí: la coordinación solo deja en
/// `sync_metadata` cuántos intentos van y cuándo toca el siguiente.
class SyncCoordinator {
  SyncCoordinator({required this._metadata, BackoffPolicy? backoff})
    : _backoff = backoff ?? BackoffPolicy();

  final SyncMetadataDao _metadata;
  final BackoffPolicy _backoff;
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
  /// Si [action] falla, el error se propaga y queda en `sync_metadata`.
  Future<T> run<T>(String resourceKey, Future<T> Function() action) {
    final existing = _inFlight[resourceKey];
    if (existing != null) return existing as Future<T>;

    final future = _execute(resourceKey, action).whenComplete(() {
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

  Future<T> _execute<T>(String key, Future<T> Function() action) async {
    _running++;
    _setStatus(SyncStatus.sincronizando);
    var outcome = const [SyncStatus.fallida];
    try {
      final previous = await _metadata.getEntry(key);
      await _metadata.upsert(
        SyncMetadataEntriesCompanion.insert(
          resourceKey: key,
          status: SyncMetadataStatus.syncing,
          lastAttemptAt: Value(clock.now()),
          nextRetryAt: const Value(null),
        ),
      );

      final T result;
      try {
        result = await action();
      } catch (error) {
        outcome = await _recordFailure(key, previous?.attempts ?? 0, error);
        rethrow;
      }

      await _metadata.upsert(
        SyncMetadataEntriesCompanion.insert(
          resourceKey: key,
          status: SyncMetadataStatus.completed,
          lastSuccessAt: Value(clock.now()),
          attempts: const Value(0),
          nextRetryAt: const Value(null),
          lastError: const Value(null),
        ),
      );
      outcome = const [SyncStatus.completada];
      return result;
    } finally {
      _finish(outcome);
    }
  }

  /// Guarda el fallo en `sync_metadata` y devuelve los estados que se publican:
  /// con intentos disponibles queda esperando el reintento; si no, vuelve a
  /// inactiva (D08). El siguiente intento espera lo que pida el backoff o,
  /// si es mayor, el `retryAfter` del 429 o del presupuesto agotado.
  Future<List<SyncStatus>> _recordFailure(
    String key,
    int previousAttempts,
    Object error,
  ) async {
    final attempts = previousAttempts + 1;
    final hasAttemptsLeft = _backoff.hasAttemptsLeft(attempts);
    final nextRetryAt = hasAttemptsLeft
        ? clock.now().add(_retryDelay(attempts, error))
        : null;
    try {
      await _metadata.upsert(
        SyncMetadataEntriesCompanion.insert(
          resourceKey: key,
          status: SyncMetadataStatus.failed,
          attempts: Value(attempts),
          nextRetryAt: Value(nextRetryAt),
          lastError: Value(error.toString()),
        ),
      );
    } catch (_) {
      // No poder registrar el fallo no debe tapar el error de la sincronización.
    }
    return [
      SyncStatus.fallida,
      hasAttemptsLeft ? SyncStatus.esperandoReintento : SyncStatus.inactiva,
    ];
  }

  Duration _retryDelay(int attempts, Object error) {
    final backoff = _backoff.delayFor(attempts);
    final requested = switch (error) {
      RateLimitFailure(:final retryAfter) ||
      BudgetExhaustedFailure(:final retryAfter) => retryAfter,
      _ => Duration.zero,
    };
    return requested > backoff ? requested : backoff;
  }

  /// Registra el fin de una ejecución; los estados terminales solo se publican
  /// cuando ya no queda ninguna en curso.
  void _finish(List<SyncStatus> terminal) {
    _running--;
    if (_running == 0) terminal.forEach(_setStatus);
  }

  void _setStatus(SyncStatus status) {
    if (_disposed || status == _status) return;
    _status = status;
    _controller.add(status);
  }
}
