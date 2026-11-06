import 'dart:async';

import 'package:regi_dex/core/connectivity/health_checker.dart';
import 'package:regi_dex/core/connectivity/network_source.dart';
import 'package:regi_dex/core/connectivity/service_status.dart';
import 'package:regi_dex/core/error/failure.dart';

/// Origen de red controlado por la prueba.
class FakeNetworkSource implements NetworkSource {
  FakeNetworkSource([NetworkKind kind = NetworkKind.wifi])
    : _state = NetworkState(kind);

  NetworkState _state;
  final _controller = StreamController<NetworkState>.broadcast(sync: true);

  @override
  Future<NetworkState> current() async => _state;

  @override
  Stream<NetworkState> get changes => _controller.stream;

  /// Cambia la interfaz activa y avisa a los oyentes.
  void change(NetworkKind kind) {
    _state = NetworkState(kind);
    _controller.add(_state);
  }
}

/// Health-check controlado por la prueba: falla con [failure] si no es null y
/// tarda [delay].
class FakeHealthChecker implements HealthChecker {
  Failure? failure;
  Duration delay = Duration.zero;

  /// Número de intento recibido en cada llamada.
  final attempts = <int>[];

  int get calls => attempts.length;

  @override
  Future<void> check({int attempt = 1}) async {
    attempts.add(attempt);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final error = failure;
    if (error != null) throw error;
  }
}
