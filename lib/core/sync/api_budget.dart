import 'package:clock/clock.dart';

import '../database/daos/api_call_log_dao.dart';
import '../error/failure.dart';

/// Reserva de una llamada a PokéAPI dentro del presupuesto.
class BudgetPermit {
  BudgetPermit._(this._log, this.id);

  final ApiCallLogDao _log;

  /// Id de la fila en `api_call_log`.
  final int id;

  /// Guarda el estado HTTP de la llamada al terminar.
  Future<void> complete(int? httpStatus) => _log.setHttpStatus(id, httpStatus);
}

/// Presupuesto de llamadas a PokéAPI (ADR-005, RNF-API-01): como máximo
/// [limit] por ventana móvil de [window], registradas en `api_call_log` para
/// que sobrevivan a un reinicio. Ante un 429 se pausa hasta `Retry-After`.
class ApiBudget {
  ApiBudget({
    required this._log,
    this.limit = 90,
    this.window = const Duration(minutes: 60),
    this.retention = const Duration(hours: 24),
  });

  final ApiCallLogDao _log;

  /// Llamadas máximas por ventana (el 90 % del límite de 100 por hora).
  final int limit;

  /// Ventana móvil del presupuesto.
  final Duration window;

  /// Tiempo que se conservan las filas del registro, para inspección.
  final Duration retention;

  DateTime? _pausedUntil;
  Future<void> _tail = Future.value();

  /// Reserva una llamada de [operation] y la registra, o devuelve null si el
  /// presupuesto está agotado o en pausa. Las reservas se serializan, así que
  /// la llamada número [limit] + 1 nunca pasa.
  Future<BudgetPermit?> tryAcquire(String operation) => _serialized(() async {
    final now = clock.now();
    if (_isPaused(now)) return null;
    await _log.purgeBefore(now.subtract(retention));
    if (await _log.countSince(now.subtract(window)) >= limit) return null;
    final id = await _log.record(operation, calledAt: now);
    return BudgetPermit._(_log, id);
  });

  /// Ejecuta [call] dentro del presupuesto y registra su estado HTTP.
  /// Lanza [BudgetExhaustedFailure] si no hay cupo; un [RateLimitFailure] de
  /// [call] pausa el presupuesto durante su `retryAfter`.
  Future<T> guard<T>(String operation, Future<T> Function() call) async {
    final permit = await tryAcquire(operation);
    if (permit == null) {
      final wait = await timeUntilAvailable();
      throw BudgetExhaustedFailure(
        'Presupuesto de llamadas a PokéAPI agotado (${wait.inSeconds} s para tener cupo)',
        retryAfter: wait,
      );
    }
    try {
      final result = await call();
      await permit.complete(200);
      return result;
    } on RateLimitFailure catch (failure) {
      pauseUntil(clock.now().add(failure.retryAfter));
      await permit.complete(429);
      rethrow;
    } on ServiceUnavailableFailure catch (failure) {
      await permit.complete(failure.statusCode);
      rethrow;
    } catch (_) {
      await permit.complete(null);
      rethrow;
    }
  }

  /// Llamadas hechas dentro de la ventana actual.
  Future<int> used() => _log.countSince(clock.now().subtract(window));

  /// Tiempo que falta para poder hacer otra llamada; cero si ya hay cupo.
  Future<Duration> timeUntilAvailable() async {
    final now = clock.now();
    final paused = _pausedUntil;
    var wait = paused != null && paused.isAfter(now)
        ? paused.difference(now)
        : Duration.zero;
    final since = now.subtract(window);
    if (await _log.countSince(since) >= limit) {
      final oldest = await _log.oldestSince(since);
      if (oldest != null) {
        final release = oldest.add(window).difference(now);
        if (release > wait) wait = release;
      }
    }
    return wait.isNegative ? Duration.zero : wait;
  }

  /// Bloquea toda llamada hasta [until] (respuesta 429 con `Retry-After`).
  void pauseUntil(DateTime until) {
    final current = _pausedUntil;
    if (current == null || until.isAfter(current)) _pausedUntil = until;
  }

  bool _isPaused(DateTime now) {
    final paused = _pausedUntil;
    return paused != null && now.isBefore(paused);
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final run = _tail.then((_) => action());
    _tail = run.then<void>((_) {}, onError: (_) {});
    return run;
  }
}
