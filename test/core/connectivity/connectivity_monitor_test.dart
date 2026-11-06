import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/connectivity/connectivity_monitor.dart';
import 'package:regi_dex/core/connectivity/service_status.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/network/graphql_operation.dart';
import 'package:regi_dex/core/network/poke_api_client.dart';
import 'package:regi_dex/core/sync/backoff_policy.dart';

import 'connectivity_fakes.dart';

const _down = ServiceUnavailableFailure(
  'PokéAPI respondió HTTP 503',
  statusCode: 503,
);

ApiCallEvent _call({Failure? failure}) => ApiCallEvent(
  operation: GraphqlOperation.getPokemonPage,
  duration: const Duration(milliseconds: 300),
  attempt: 1,
  failure: failure,
);

/// Monitor con red, health-check y flujo de llamadas falsos. Se crea dentro de
/// `fakeAsync`, para que sus temporizadores usen el reloj falso.
class _Harness {
  _Harness({NetworkKind network = NetworkKind.wifi, Failure? failure}) {
    networkSource = FakeNetworkSource(network);
    checker = FakeHealthChecker()..failure = failure;
    monitor = ConnectivityMonitor(
      network: networkSource,
      healthChecker: checker,
      calls: calls.stream,
      backoff: BackoffPolicy(jitter: 0),
      log: logs.add,
    );
    monitor.snapshots.listen(snapshots.add);
  }

  final calls = StreamController<ApiCallEvent>.broadcast(sync: true);
  final snapshots = <ConnectivitySnapshot>[];
  final logs = <String>[];
  late final FakeNetworkSource networkSource;
  late final FakeHealthChecker checker;
  late final ConnectivityMonitor monitor;

  List<ServiceStatus> get statuses => [for (final s in snapshots) s.status];

  ServiceStatus get status => monitor.current.status;

  /// Arranca el monitor y deja correr las microtareas pendientes.
  void start(FakeAsync async) {
    unawaited(monitor.start());
    async.flushMicrotasks();
  }
}

void main() {
  group('arranque', () {
    test('con red y API sana pasa a online al instante', () {
      fakeAsync((async) {
        final h = _Harness();
        h.start(async);

        expect(h.statuses.first, ServiceStatus.verificando);
        expect(h.status, ServiceStatus.online);
        expect(h.checker.calls, 1);
        expect(h.snapshots.any((s) => s.isVerifying), isTrue);
        expect(h.monitor.current.isVerifying, isFalse);
        expect(h.monitor.current.networkKind, NetworkKind.wifi);
        expect(h.monitor.current.lastFailure, isNull);
        expect(h.monitor.current.lastCheckAt, isNotNull);
        h.monitor.dispose();
      });
    });

    test('sin interfaz de red queda offline sin gastar llamadas', () {
      fakeAsync((async) {
        final h = _Harness(network: NetworkKind.none);
        h.start(async);

        expect(h.status, ServiceStatus.offline);
        expect(h.checker.calls, 0);
        h.monitor.dispose();
      });
    });

    test(
      'Wi-Fi activo con API caída da servicioNoDisponible y nunca online',
      () {
        fakeAsync((async) {
          final h = _Harness(failure: _down);
          h.start(async);
          async.elapse(const Duration(minutes: 2));

          expect(h.status, ServiceStatus.servicioNoDisponible);
          expect(h.statuses, isNot(contains(ServiceStatus.online)));
          expect(h.monitor.current.lastFailure, _down);
          expect(h.monitor.current.networkKind, NetworkKind.wifi);
          h.monitor.dispose();
        });
      },
    );

    test('cada fallo de servicio se clasifica como servicioNoDisponible', () {
      const failures = <Failure>[
        TimeoutFailure(),
        NetworkFailure(),
        RateLimitFailure('429', retryAfter: Duration(seconds: 60)),
        GraphQLFailure('error de esquema'),
        _down,
      ];
      for (final failure in failures) {
        fakeAsync((async) {
          final h = _Harness(failure: failure);
          h.start(async);

          expect(
            h.status,
            ServiceStatus.servicioNoDisponible,
            reason: '$failure',
          );
          h.monitor.dispose();
        });
      }
    });

    test('un fallo de red cuando la interfaz cayó durante la verificación es offline', () {
      fakeAsync((async) {
        final h = _Harness(failure: const NetworkFailure());
        h.checker.delay = const Duration(seconds: 1);
        h.start(async);

        h.networkSource.change(NetworkKind.none);
        async.elapse(const Duration(seconds: 2));

        expect(h.status, ServiceStatus.offline);
        h.monitor.dispose();
      });
    });
  });

  group('histéresis de 1.5 s', () {
    test('un corte de red menor a 1.5 s no se muestra', () {
      fakeAsync((async) {
        final h = _Harness();
        h.start(async);

        h.networkSource.change(NetworkKind.none);
        async.elapse(const Duration(seconds: 1));
        h.networkSource.change(NetworkKind.wifi);
        async.elapse(const Duration(seconds: 5));

        expect(h.statuses, isNot(contains(ServiceStatus.offline)));
        expect(h.status, ServiceStatus.online);
        expect(h.checker.calls, 2); // el regreso de la red confirma con un ping
        h.monitor.dispose();
      });
    });

    test('un corte de 1.5 s o más pasa a offline justo al cumplirse', () {
      fakeAsync((async) {
        final h = _Harness();
        h.start(async);

        h.networkSource.change(NetworkKind.none);
        async.elapse(const Duration(milliseconds: 1499));
        expect(h.status, ServiceStatus.online);

        async.elapse(const Duration(milliseconds: 1));
        expect(h.status, ServiceStatus.offline);
        h.monitor.dispose();
      });
    });

    test(
      'al volver la red confirma con un ping y muestra online tras 1.5 s',
      () {
        fakeAsync((async) {
          final h = _Harness();
          h.start(async);
          h.networkSource.change(NetworkKind.none);
          async.elapse(const Duration(seconds: 2));
          expect(h.status, ServiceStatus.offline);

          h.networkSource.change(NetworkKind.mobile);
          async.elapse(const Duration(milliseconds: 1400));
          expect(h.status, ServiceStatus.offline);
          expect(h.checker.calls, 2);

          async.elapse(const Duration(milliseconds: 100));
          expect(h.status, ServiceStatus.online);
          expect(h.monitor.current.networkKind, NetworkKind.mobile);
          h.monitor.dispose();
        });
      },
    );

    test('una caída del servicio se muestra tras 1.5 s sostenida', () {
      fakeAsync((async) {
        final h = _Harness();
        h.start(async);

        h.checker.failure = _down;
        unawaited(h.monitor.checkNow());
        async.elapse(const Duration(milliseconds: 1400));
        expect(h.status, ServiceStatus.online);

        async.elapse(const Duration(milliseconds: 100));
        expect(h.status, ServiceStatus.servicioNoDisponible);
        h.monitor.dispose();
      });
    });

    test('un fallo que se recupera antes de 1.5 s no se muestra', () {
      fakeAsync((async) {
        final h = _Harness();
        h.start(async);

        h.checker.failure = _down;
        unawaited(h.monitor.checkNow());
        async.elapse(const Duration(seconds: 1));
        h.calls.add(_call()); // una consulta real sale bien
        async.elapse(const Duration(seconds: 5));

        expect(h.statuses, isNot(contains(ServiceStatus.servicioNoDisponible)));
        expect(h.status, ServiceStatus.online);
        h.monitor.dispose();
      });
    });

    test('mientras verifica conserva el último estado estable', () {
      fakeAsync((async) {
        final h = _Harness();
        h.start(async);

        h.checker.delay = const Duration(seconds: 2);
        unawaited(h.monitor.checkNow());
        async.flushMicrotasks();
        expect(h.monitor.current.isVerifying, isTrue);
        expect(h.status, ServiceStatus.online);

        async.elapse(const Duration(seconds: 2));
        expect(h.monitor.current.isVerifying, isFalse);
        expect(h.status, ServiceStatus.online);
        h.monitor.dispose();
      });
    });
  });

  group('consultas reales', () {
    test(
      'una consulta exitosa cuenta como health-check y detiene los reintentos',
      () {
        fakeAsync((async) {
          final h = _Harness(failure: _down);
          h.start(async);
          expect(h.status, ServiceStatus.servicioNoDisponible);

          async.elapse(const Duration(milliseconds: 500));
          h.calls.add(_call());
          async.elapse(const Duration(minutes: 1));

          expect(h.status, ServiceStatus.online);
          expect(h.checker.calls, 1); // ningún ping extra
          expect(h.monitor.current.nextRetryAt, isNull);
          h.monitor.dispose();
        });
      },
    );

    test('una consulta fallida por el servicio lo marca no disponible', () {
      fakeAsync((async) {
        final h = _Harness();
        h.start(async);

        h.calls.add(_call(failure: _down));
        async.elapse(const Duration(seconds: 2));

        expect(h.status, ServiceStatus.servicioNoDisponible);
        h.monitor.dispose();
      });
    });

    test('los fallos que no hablan del servicio no cambian el estado', () {
      fakeAsync((async) {
        final h = _Harness();
        h.start(async);

        h.calls
          ..add(_call(failure: const ValidationFailure('dto inválido')))
          ..add(_call(failure: const PartialDataFailure('parcial', data: {})))
          ..add(
            _call(failure: const GraphQLFailure('mal', isValidation: true)),
          );
        async.elapse(const Duration(seconds: 10));

        expect(h.status, ServiceStatus.online);
        expect(h.monitor.current.lastFailure, isNull);
        h.monitor.dispose();
      });
    });
  });

  group('reintentos con backoff', () {
    test('reintenta a los 2, 4, 8, 16 y 32 s y luego se detiene', () {
      fakeAsync((async) {
        final h = _Harness(failure: _down);
        h.start(async);
        expect(h.checker.attempts, [1]);
        expect(
          h.monitor.current.nextRetryAt!.difference(clock.now()),
          const Duration(seconds: 2),
        );

        for (final seconds in [2, 4, 8, 16, 32]) {
          async.elapse(Duration(seconds: seconds));
        }
        expect(h.checker.attempts, [1, 2, 3, 4, 5, 6]);
        expect(h.monitor.current.nextRetryAt, isNull);

        async.elapse(const Duration(minutes: 9));
        expect(h.checker.calls, 6); // ya no reintenta solo
        expect(h.status, ServiceStatus.servicioNoDisponible);
        h.monitor.dispose();
      });
    });

    test(
      'tras agotar los reintentos manda un ping a los 10 min sin tráfico',
      () {
        fakeAsync((async) {
          final h = _Harness(failure: _down);
          h.start(async);
          async.elapse(const Duration(seconds: 62)); // 2 + 4 + 8 + 16 + 32
          expect(h.checker.calls, 6);

          async.elapse(const Duration(seconds: 599));
          expect(h.checker.calls, 6);
          async.elapse(const Duration(seconds: 1));
          expect(h.checker.calls, 7);
          h.monitor.dispose();
        });
      },
    );

    test('recupera cuando un reintento responde y reinicia la cuenta', () {
      fakeAsync((async) {
        final h = _Harness(failure: _down);
        h.start(async);

        async.elapse(const Duration(seconds: 2)); // segundo intento, falla
        h.checker.failure = null;
        async.elapse(const Duration(seconds: 4)); // tercer intento, responde
        async.elapse(const Duration(seconds: 2));
        expect(h.status, ServiceStatus.online);
        expect(h.monitor.current.lastFailure, isNull);

        h.checker.failure = _down;
        unawaited(h.monitor.checkNow());
        async.elapse(const Duration(seconds: 2));
        expect(
          h.checker.attempts.last,
          2,
        ); // vuelve a empezar: reintento a los 2 s
        h.monitor.dispose();
      });
    });

    test('sin interfaz de red no reintenta', () {
      fakeAsync((async) {
        final h = _Harness(failure: _down);
        h.start(async);
        h.networkSource.change(NetworkKind.none);
        final callsBefore = h.checker.calls;

        async.elapse(const Duration(minutes: 5));

        expect(h.checker.calls, callsBefore);
        expect(h.status, ServiceStatus.offline);
        h.monitor.dispose();
      });
    });

    test('cada intento se registra en consola', () {
      fakeAsync((async) {
        final h = _Harness(failure: _down);
        h.start(async);
        async.elapse(const Duration(seconds: 2));

        expect(h.logs, contains(contains('reintento 1 de 5 en 2.0 s')));
        expect(h.logs, contains(contains('reintento 2 de 5 en 4.0 s')));
        expect(
          h.logs,
          contains(contains('verificando → servicioNoDisponible')),
        );
        h.monitor.dispose();
      });
    });
  });

  group('pings explícitos', () {
    test('manda un ping a los 10 min sin tráfico, no antes', () {
      fakeAsync((async) {
        final h = _Harness();
        h.start(async);

        async.elapse(const Duration(minutes: 9, seconds: 59));
        expect(h.checker.calls, 1);
        async.elapse(const Duration(seconds: 1));
        expect(h.checker.calls, 2);
        h.monitor.dispose();
      });
    });

    test('el tráfico reinicia la cuenta de los 10 min', () {
      fakeAsync((async) {
        final h = _Harness();
        h.start(async);

        async.elapse(const Duration(minutes: 5));
        h.calls.add(_call());
        async.elapse(const Duration(minutes: 5));
        expect(h.checker.calls, 1);

        async.elapse(const Duration(minutes: 5));
        expect(h.checker.calls, 2);
        h.monitor.dispose();
      });
    });

    test('un cambio de red manda un ping y repetir el mismo estado no', () {
      fakeAsync((async) {
        final h = _Harness();
        h.start(async);

        h.networkSource.change(NetworkKind.mobile);
        async.flushMicrotasks();
        expect(h.checker.calls, 2);
        expect(h.monitor.current.networkKind, NetworkKind.mobile);

        h.networkSource.change(NetworkKind.mobile);
        async.flushMicrotasks();
        expect(h.checker.calls, 2);
        h.monitor.dispose();
      });
    });

    test('checkNow fuerza un ping y reinicia los reintentos', () {
      fakeAsync((async) {
        final h = _Harness(failure: _down);
        h.start(async);
        async.elapse(const Duration(seconds: 62));
        expect(h.checker.calls, 6);

        unawaited(h.monitor.checkNow());
        async.flushMicrotasks();
        expect(h.checker.calls, 7);
        expect(h.checker.attempts.last, 1);

        async.elapse(const Duration(seconds: 2));
        expect(h.checker.calls, 8); // vuelve a reintentar
        h.monitor.dispose();
      });
    });

    test('checkNow sin interfaz de red no hace nada', () {
      fakeAsync((async) {
        final h = _Harness(network: NetworkKind.none);
        h.start(async);

        unawaited(h.monitor.checkNow());
        async.flushMicrotasks();

        expect(h.checker.calls, 0);
        h.monitor.dispose();
      });
    });

    test('dos checkNow simultáneos comparten una sola verificación', () {
      fakeAsync((async) {
        final h = _Harness();
        h.start(async);
        h.checker.delay = const Duration(seconds: 1);

        final first = h.monitor.checkNow();
        final second = h.monitor.checkNow();
        async.elapse(const Duration(seconds: 2));

        expect(identical(first, second), isTrue);
        expect(h.checker.calls, 2);
        h.monitor.dispose();
      });
    });
  });

  group('ciclo de vida', () {
    test('snapshots entrega el estado actual al suscribirse', () {
      fakeAsync((async) {
        final h = _Harness();
        h.start(async);

        final received = <ConnectivitySnapshot>[];
        h.monitor.snapshots.listen(received.add);
        async.flushMicrotasks();

        expect(received.single.status, ServiceStatus.online);
        h.monitor.dispose();
      });
    });

    test('statuses no repite el mismo estado', () {
      fakeAsync((async) {
        final h = _Harness();
        final received = <ServiceStatus>[];
        h.monitor.statuses.listen(received.add);
        h.start(async);
        h.networkSource.change(NetworkKind.mobile);
        async.elapse(const Duration(seconds: 5));

        expect(received, [ServiceStatus.verificando, ServiceStatus.online]);
        h.monitor.dispose();
      });
    });

    test('dispose cancela los temporizadores y deja de escuchar', () {
      fakeAsync((async) {
        final h = _Harness(failure: _down);
        h.start(async);

        h.monitor.dispose();
        async.elapse(const Duration(hours: 1));

        expect(h.checker.calls, 1);
        expect(async.nonPeriodicTimerCount, 0);
        h.networkSource.change(NetworkKind.none); // ya no escucha
        async.flushMicrotasks();
        expect(h.checker.calls, 1);
      });
    });

    test('dispose cierra el flujo de snapshots', () async {
      final h = _Harness();
      await h.monitor.start();
      final done = Completer<void>();
      h.monitor.snapshots.listen((_) {}, onDone: done.complete);

      h.monitor.dispose();

      await expectLater(done.future, completes);
    });
  });
}
