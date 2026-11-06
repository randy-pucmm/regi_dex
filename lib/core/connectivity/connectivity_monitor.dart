import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../error/failure.dart';
import '../network/poke_api_client.dart';
import '../sync/backoff_policy.dart';
import 'health_checker.dart';
import 'network_source.dart';
import 'service_status.dart';

/// Monitor de la disponibilidad real de PokéAPI (ADR-007, OF-11, IND-02).
///
/// Los eventos de red son solo una pista; la verdad la da el health-check. Las
/// consultas reales exitosas cuentan como health-check y el ping explícito se
/// envía al cambiar la red, al reintentar tras una caída y tras 10 minutos sin
/// tráfico. Un estado nuevo debe sostenerse [hysteresis] antes de mostrarse
/// (IND-06); mientras se verifica se conserva el último estado estable.
///
/// Uso: crear, llamar a [start] y observar [snapshots]; [dispose] al terminar.
class ConnectivityMonitor {
  ConnectivityMonitor({
    required NetworkSource network,
    required this._healthChecker,
    required this._calls,
    BackoffPolicy? backoff,
    this.hysteresis = const Duration(milliseconds: 1500),
    this.idleInterval = const Duration(minutes: 10),
    void Function(String message)? log,
  }) : _networkSource = network,
       _backoff = backoff ?? BackoffPolicy(),
       _log = log ?? debugPrint {
    _current = _snapshot();
  }

  /// Tiempo que un estado nuevo debe sostenerse antes de mostrarse.
  final Duration hysteresis;

  /// Tiempo sin tráfico tras el cual se envía un ping.
  final Duration idleInterval;

  final NetworkSource _networkSource;
  final HealthChecker _healthChecker;
  final Stream<ApiCallEvent> _calls;
  final BackoffPolicy _backoff;
  final void Function(String message) _log;
  final _controller = StreamController<ConnectivitySnapshot>.broadcast();

  StreamSubscription<NetworkState>? _networkSub;
  StreamSubscription<ApiCallEvent>? _callsSub;
  Timer? _pendingTimer;
  Timer? _retryTimer;
  Timer? _idleTimer;
  Future<void>? _inFlight;

  var _network = const NetworkState(NetworkKind.none);
  var _stable = ServiceStatus.verificando;
  ServiceStatus? _pending;
  var _verifying = false;
  var _retryAttempt = 0;
  Failure? _lastFailure;
  DateTime? _lastCheckAt;
  DateTime? _nextRetryAt;
  var _started = false;
  var _disposed = false;
  late ConnectivitySnapshot _current;

  /// Estado actual.
  ConnectivitySnapshot get current => _current;

  /// Estados del monitor: emite el actual al suscribirse y luego cada cambio.
  Stream<ConnectivitySnapshot> get snapshots {
    late final StreamController<ConnectivitySnapshot> controller;
    StreamSubscription<ConnectivitySnapshot>? subscription;
    controller = StreamController<ConnectivitySnapshot>(
      onListen: () {
        controller.add(_current);
        subscription = _controller.stream.listen(
          controller.add,
          onDone: controller.close,
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  /// Solo el estado de servicio, sin repetir valores.
  Stream<ServiceStatus> get statuses =>
      snapshots.map((snapshot) => snapshot.status).distinct();

  /// Lee la red actual y confirma con un health-check. Si no hay interfaz de
  /// red, queda en [ServiceStatus.offline] sin gastar ninguna llamada.
  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    try {
      _network = await _networkSource.current();
    } catch (_) {
      // Sin dato de la plataforma, el health-check decide.
      _network = const NetworkState(NetworkKind.other);
    }
    if (_disposed) return;
    _networkSub = _networkSource.changes.listen(_onNetworkChanged);
    _callsSub = _calls.listen(_onCall);
    _armIdleTimer();
    if (_network.hasInterface) {
      await _runCheck();
    } else {
      _propose(ServiceStatus.offline);
      _emit();
    }
  }

  /// Fuerza un health-check ya y reinicia los reintentos («Sincronizar ahora»).
  /// No hace nada sin interfaz de red.
  Future<void> checkNow() {
    if (_disposed || !_network.hasInterface) return Future.value();
    _cancelRetry();
    _retryAttempt = 0;
    return _runCheck();
  }

  /// Cancela los temporizadores y las suscripciones.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_networkSub?.cancel());
    unawaited(_callsSub?.cancel());
    _pendingTimer?.cancel();
    _retryTimer?.cancel();
    _idleTimer?.cancel();
    unawaited(_controller.close());
  }

  void _onNetworkChanged(NetworkState state) {
    if (state == _network) return;
    _network = state;
    if (!state.hasInterface) {
      _cancelRetry();
      _propose(ServiceStatus.offline);
      _emit();
      return;
    }
    // Volvió la red: un corte corto no debe mostrarse, y el health-check confirma.
    if (_pending == ServiceStatus.offline) _cancelPending();
    _cancelRetry();
    _retryAttempt = 0;
    _emit();
    unawaited(_runCheck());
  }

  void _onCall(ApiCallEvent event) {
    _armIdleTimer();
    final failure = event.failure;
    if (failure == null) {
      _handleSuccess();
    } else {
      _handleFailure(failure);
    }
  }

  Future<void> _runCheck() =>
      _inFlight ??= _check().whenComplete(() => _inFlight = null);

  Future<void> _check() async {
    _verifying = true;
    _emit();
    try {
      await _healthChecker.check(attempt: _retryAttempt + 1);
      if (!_disposed) _handleSuccess();
    } on Failure catch (failure) {
      if (!_disposed) _handleFailure(failure);
    } catch (error) {
      if (!_disposed) {
        _handleFailure(
          ServiceUnavailableFailure(
            'Fallo inesperado en el health-check: $error',
          ),
        );
      }
    } finally {
      _verifying = false;
      _emit();
    }
  }

  void _handleSuccess() {
    _armIdleTimer();
    _lastFailure = null;
    _lastCheckAt = clock.now();
    _retryAttempt = 0;
    _cancelRetry();
    _propose(ServiceStatus.online);
    _emit();
  }

  void _handleFailure(Failure failure) {
    final status = _classify(failure);
    if (status == null) return;
    _armIdleTimer();
    _lastFailure = failure;
    _lastCheckAt = clock.now();
    _propose(status);
    if (status == ServiceStatus.servicioNoDisponible) {
      _scheduleRetry();
    } else {
      _cancelRetry();
    }
    _emit();
  }

  /// Estado de servicio que implica [failure], o null si no habla del servicio
  /// (un DTO inválido o una consulta mal formada no lo cambian).
  ServiceStatus? _classify(Failure failure) {
    if (!_network.hasInterface) return ServiceStatus.offline;
    return switch (failure) {
      NetworkFailure() ||
      TimeoutFailure() ||
      ServiceUnavailableFailure() ||
      RateLimitFailure() => ServiceStatus.servicioNoDisponible,
      GraphQLFailure(isValidation: false) => ServiceStatus.servicioNoDisponible,
      GraphQLFailure() || PartialDataFailure() || ValidationFailure() => null,
    };
  }

  /// Propone [candidate] como estado: el primero se muestra al instante y los
  /// siguientes solo si se sostienen [hysteresis].
  void _propose(ServiceStatus candidate) {
    if (_stable == ServiceStatus.verificando) {
      _commit(candidate);
    } else if (candidate == _stable) {
      _cancelPending();
    } else if (_pending != candidate) {
      _pendingTimer?.cancel();
      _pending = candidate;
      _pendingTimer = Timer(hysteresis, () => _commit(candidate));
    }
  }

  void _commit(ServiceStatus status) {
    _cancelPending();
    if (_stable == status) return;
    _log('[Conectividad] ${_stable.name} → ${status.name}${_reason()}');
    _stable = status;
    _emit();
  }

  String _reason() {
    final failure = _lastFailure;
    return failure == null ? '' : ' ($failure)';
  }

  void _cancelPending() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
    _pending = null;
  }

  void _scheduleRetry() {
    if (_disposed || !_network.hasInterface) return;
    if (_retryTimer?.isActive ?? false) return;
    if (!_backoff.hasAttemptsLeft(_retryAttempt)) return;
    final attempt = _retryAttempt + 1;
    final delay = _backoff.delayFor(attempt);
    _nextRetryAt = clock.now().add(delay);
    _log(
      '[Conectividad] reintento $attempt de ${_backoff.maxAttempts} '
      'en ${delay.inMilliseconds / 1000} s',
    );
    _retryTimer = Timer(delay, () {
      _nextRetryAt = null;
      _retryAttempt = attempt;
      unawaited(_runCheck());
    });
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _nextRetryAt = null;
  }

  void _armIdleTimer() {
    if (_disposed) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(idleInterval, () {
      if (_network.hasInterface) unawaited(_runCheck());
    });
  }

  ConnectivitySnapshot _snapshot() => ConnectivitySnapshot(
    status: _stable,
    isVerifying: _verifying,
    networkKind: _network.kind,
    lastFailure: _lastFailure,
    lastCheckAt: _lastCheckAt,
    nextRetryAt: _nextRetryAt,
  );

  void _emit() {
    if (_disposed) return;
    final snapshot = _snapshot();
    if (snapshot == _current) return;
    _current = snapshot;
    _controller.add(snapshot);
  }
}
