import 'dart:async';

import 'package:clock/clock.dart';

import '../database/app_database.dart';
import 'sync_coordinator.dart';

/// Reintenta solo las sincronizaciones fallidas (RNF-RES-02, RNF-RES-06).
///
/// Lee las filas de `sync_metadata` con `status = failed` y `nextRetryAt`, que
/// el [SyncCoordinator] ya calculó con backoff y `Retry-After`, y lanza
/// [retry] cuando llega esa hora. Si el servicio no está disponible a la hora
/// del reintento no hace nada y no gasta intentos: [onServiceOnline] lo retoma
/// al volver el servicio.
///
/// Uso: crear con el flujo de filas, `start()` y `dispose()` al terminar.
class SyncRetryScheduler {
  /// [rows] emite el estado de todos los recursos; [isOnline] dice si hay
  /// servicio; [retry] relanza el recurso con esa clave; [handles] filtra las
  /// claves que este planificador reintenta (por defecto, todas).
  SyncRetryScheduler({
    required this._rows,
    required this._isOnline,
    required this._retry,
    bool Function(String resourceKey)? handles,
  }) : _handles = handles ?? ((_) => true);

  final Stream<List<SyncMetadataRow>> _rows;
  final bool Function() _isOnline;
  final Future<void> Function(String resourceKey) _retry;
  final bool Function(String resourceKey) _handles;

  final _due = <String, DateTime>{};
  final _timers = <String, Timer>{};
  StreamSubscription<List<SyncMetadataRow>>? _subscription;
  var _disposed = false;

  /// Empieza a observar `sync_metadata`.
  void start() {
    if (_disposed || _subscription != null) return;
    _subscription = _rows.listen(_onRows);
  }

  /// Retoma ya los reintentos cuya hora pasó mientras no había servicio.
  void onServiceOnline() {
    if (_disposed) return;
    final now = clock.now();
    for (final key in [..._due.keys]) {
      if (!_due[key]!.isAfter(now)) _fire(key);
    }
  }

  /// Cancela los temporizadores y la suscripción.
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _due.clear();
  }

  void _onRows(List<SyncMetadataRow> rows) {
    final next = {
      for (final row in rows)
        if (row.status == SyncMetadataStatus.failed &&
            row.nextRetryAt != null &&
            _handles(row.resourceKey))
          row.resourceKey: row.nextRetryAt!,
    };
    for (final key in [..._due.keys]) {
      if (next[key] != _due[key]) {
        _timers.remove(key)?.cancel();
        _due.remove(key);
      }
    }
    next.forEach((key, at) {
      if (_due.containsKey(key)) return;
      _due[key] = at;
      final wait = at.difference(clock.now());
      _timers[key] = Timer(wait.isNegative ? Duration.zero : wait, () {
        _timers.remove(key);
        if (_isOnline()) _fire(key);
      });
    });
  }

  void _fire(String key) {
    _timers.remove(key)?.cancel();
    _due.remove(key);
    unawaited(_run(key));
  }

  Future<void> _run(String key) async {
    try {
      await _retry(key);
    } catch (_) {
      // El coordinador ya registró el fallo y programó el siguiente intento.
    }
  }
}
