import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/sync/backoff_policy.dart';
import 'package:regi_dex/core/sync/sync_coordinator.dart';
import 'package:regi_dex/core/sync/sync_status.dart';

import '../database/database_test_helpers.dart';
import 'fake_time.dart';

const _down = ServiceUnavailableFailure('caída', statusCode: 503);

void main() {
  late AppDatabase db;
  late FakeTime time;
  late SyncCoordinator coordinator;

  setUp(() {
    db = createTestDatabase();
    time = FakeTime();
    coordinator = SyncCoordinator(
      metadata: db.syncMetadataDao,
      backoff: BackoffPolicy(jitter: 0),
    );
  });
  tearDown(() async {
    coordinator.dispose();
    await db.close();
  });

  Future<SyncMetadataRow> metadataOf(String key) async =>
      (await db.syncMetadataDao.getEntry(key))!;

  /// Ejecuta una sincronización que falla con [failure] y espera el error.
  Future<void> failOnce(String key, [Object failure = _down]) => time.run(
    () => expectLater(
      coordinator.run<void>(key, () async => throw failure),
      throwsA(anything),
    ),
  );

  group('single-flight', () {
    test(
      'dos solicitudes simultáneas del mismo recurso ejecutan una sola acción',
      () => time.run(() async {
        var runs = 0;
        final gate = Completer<int>();
        Future<int> action() {
          runs++;
          return gate.future;
        }

        final first = coordinator.run('catalog', action);
        final second = coordinator.run('catalog', action);
        expect(identical(first, second), isTrue);
        expect(coordinator.isRunning('catalog'), isTrue);

        gate.complete(7);

        expect(await first, 7);
        expect(await second, 7);
        expect(runs, 1);
        expect(coordinator.isRunning('catalog'), isFalse);
      }),
    );

    test(
      'terminada la ejecución, una nueva solicitud sí corre',
      () => time.run(() async {
        var runs = 0;
        Future<int> action() async => ++runs;

        expect(await coordinator.run('catalog', action), 1);
        expect(await coordinator.run('catalog', action), 2);
      }),
    );

    test(
      'recursos distintos corren en paralelo',
      () => time.run(() async {
        final gates = {
          'reference': Completer<String>(),
          'catalog': Completer<String>(),
        };
        final futures = {
          for (final entry in gates.entries)
            entry.key: coordinator.run(entry.key, () => entry.value.future),
        };

        expect(coordinator.isRunning('reference'), isTrue);
        expect(coordinator.isRunning('catalog'), isTrue);

        gates['catalog']!.complete('c');
        gates['reference']!.complete('r');
        expect(await futures['catalog'], 'c');
        expect(await futures['reference'], 'r');
      }),
    );

    test(
      'un error llega a todos los que esperan y no deja la clave atascada',
      () => time.run(() async {
        final gate = Completer<int>();
        final first = coordinator.run('catalog', () => gate.future);
        final second = coordinator.run('catalog', () => gate.future);

        await pumpEventQueue(); // deja que la acción arranque y escuche el Future
        gate.completeError(_down);
        await Future.wait([
          expectLater(first, throwsA(_down)),
          expectLater(second, throwsA(_down)),
        ]);

        expect(coordinator.isRunning('catalog'), isFalse);
        expect(await coordinator.run('catalog', () async => 1), 1);
      }),
    );
  });

  group('sync_metadata', () {
    test(
      'una sincronización exitosa guarda el éxito y conserva el cursor',
      () => time.run(() async {
        await db.syncMetadataDao.upsert(
          SyncMetadataEntriesCompanion.insert(
            resourceKey: 'catalog',
            status: 'failed',
            attempts: const Value(3),
            cursorOffset: const Value(400),
            lastError: const Value('antes'),
            nextRetryAt: Value(time.now),
          ),
        );

        await coordinator.run('catalog', () async {});

        final row = await metadataOf('catalog');
        expect(row.status, SyncMetadataStatus.completed);
        expect(row.lastSuccessAt, time.now);
        expect(row.lastAttemptAt, time.now);
        expect(row.attempts, 0);
        expect(row.nextRetryAt, isNull);
        expect(row.lastError, isNull);
        expect(row.cursorOffset, 400);
      }),
    );

    test(
      'mientras corre, el recurso figura como syncing',
      () => time.run(() async {
        final gate = Completer<void>();
        final future = coordinator.run('reference', () => gate.future);
        await pumpEventQueue();

        final row = await metadataOf('reference');
        expect(row.status, SyncMetadataStatus.syncing);
        expect(row.lastAttemptAt, time.now);

        gate.complete();
        await future;
      }),
    );

    test(
      'un fallo guarda el error, los intentos y el próximo reintento',
      () async {
        await failOnce('catalog');

        var row = await metadataOf('catalog');
        expect(row.status, SyncMetadataStatus.failed);
        expect(row.attempts, 1);
        expect(row.lastError, contains('caída'));
        expect(row.nextRetryAt, time.now.add(const Duration(seconds: 2)));

        time.advance(const Duration(seconds: 2));
        await failOnce('catalog');

        row = await metadataOf('catalog');
        expect(row.attempts, 2);
        expect(row.nextRetryAt, time.now.add(const Duration(seconds: 4)));
      },
    );

    test('un éxito después de fallos reinicia los intentos', () async {
      await failOnce('catalog');
      await failOnce('catalog');
      await time.run(() => coordinator.run('catalog', () async {}));

      final row = await metadataOf('catalog');
      expect(row.status, SyncMetadataStatus.completed);
      expect(row.attempts, 0);
      expect(row.nextRetryAt, isNull);
      expect(row.lastError, isNull);
    });

    test('al quinto fallo ya no hay próximo reintento', () async {
      for (var i = 0; i < 4; i++) {
        await failOnce('catalog');
      }
      expect((await metadataOf('catalog')).nextRetryAt, isNotNull);

      await failOnce('catalog');

      final row = await metadataOf('catalog');
      expect(row.attempts, 5);
      expect(row.status, SyncMetadataStatus.failed);
      expect(row.nextRetryAt, isNull);
    });

    test('un 429 o un presupuesto agotado esperan lo que pidan si es más que el backoff', () async {
      await failOnce(
        'a',
        const RateLimitFailure('429', retryAfter: Duration(seconds: 120)),
      );
      expect(
        (await metadataOf('a')).nextRetryAt,
        time.now.add(const Duration(seconds: 120)),
      );

      await failOnce(
        'b',
        const BudgetExhaustedFailure(
          'agotado',
          retryAfter: Duration(minutes: 20),
        ),
      );
      expect(
        (await metadataOf('b')).nextRetryAt,
        time.now.add(const Duration(minutes: 20)),
      );

      await failOnce(
        'c',
        const RateLimitFailure('429', retryAfter: Duration(seconds: 1)),
      );
      expect(
        (await metadataOf('c')).nextRetryAt,
        time.now.add(const Duration(seconds: 2)),
      );
    });

    test('registra también los errores que no son Failure', () async {
      await failOnce('catalog', StateError('bug'));

      expect((await metadataOf('catalog')).lastError, contains('bug'));
    });

    test(
      'cada recurso lleva su propio registro',
      () => time.run(() async {
        await coordinator.run('reference', () async {});
        await expectLater(
          coordinator.run<void>('catalog', () async => throw _down),
          throwsA(anything),
        );

        expect(
          (await metadataOf('reference')).status,
          SyncMetadataStatus.completed,
        );
        expect((await metadataOf('catalog')).status, SyncMetadataStatus.failed);
      }),
    );
  });

  group('SyncStatus', () {
    late List<SyncStatus> emitted;

    setUp(() async {
      emitted = [];
      coordinator.statuses.listen(emitted.add);
      await pumpEventQueue();
    });

    test('arranca inactiva', () {
      expect(emitted, [SyncStatus.inactiva]);
      expect(coordinator.status, SyncStatus.inactiva);
    });

    test(
      'éxito: sincronizando y completada',
      () => time.run(() async {
        await coordinator.run('catalog', () async {});
        await pumpEventQueue();

        expect(emitted, [
          SyncStatus.inactiva,
          SyncStatus.sincronizando,
          SyncStatus.completada,
        ]);
      }),
    );

    test(
      'fallo con intentos disponibles: fallida y esperando reintento',
      () async {
        await failOnce('catalog');
        await pumpEventQueue();

        expect(emitted, [
          SyncStatus.inactiva,
          SyncStatus.sincronizando,
          SyncStatus.fallida,
          SyncStatus.esperandoReintento,
        ]);
      },
    );

    test('al agotar los 5 intentos vuelve a inactiva', () async {
      for (var i = 0; i < 4; i++) {
        await failOnce('catalog');
      }
      await pumpEventQueue();
      emitted.clear();

      await failOnce('catalog');
      await pumpEventQueue();

      expect(emitted, [
        SyncStatus.sincronizando,
        SyncStatus.fallida,
        SyncStatus.inactiva,
      ]);
    });

    test(
      'con dos recursos sigue sincronizando hasta que terminan ambos',
      () => time.run(() async {
        final first = Completer<void>();
        final second = Completer<void>();
        final futures = [
          coordinator.run('reference', () => first.future),
          coordinator.run('catalog', () => second.future),
        ];
        await pumpEventQueue();
        expect(coordinator.status, SyncStatus.sincronizando);

        first.complete();
        await pumpEventQueue();
        expect(coordinator.status, SyncStatus.sincronizando);

        second.complete();
        await Future.wait(futures);
        await pumpEventQueue();
        expect(coordinator.status, SyncStatus.completada);
        expect(emitted.where((s) => s == SyncStatus.completada), hasLength(1));
      }),
    );

    test(
      'statuses entrega el estado actual al suscribirse',
      () => time.run(() async {
        await coordinator.run('catalog', () async {});
        final received = <SyncStatus>[];

        coordinator.statuses.listen(received.add);
        await pumpEventQueue();

        expect(received, [SyncStatus.completada]);
      }),
    );
  });

  test('dispose cierra el flujo de estados', () async {
    final done = Completer<void>();
    coordinator.statuses.listen((_) {}, onDone: done.complete);

    coordinator.dispose();

    await expectLater(done.future, completes);
  });
}
