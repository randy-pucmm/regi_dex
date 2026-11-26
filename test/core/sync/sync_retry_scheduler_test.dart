import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/sync/sync_coordinator.dart';
import 'package:regi_dex/core/sync/sync_retry_scheduler.dart';

SyncMetadataRow _failed(String key, DateTime? retryAt, {int attempts = 1}) =>
    SyncMetadataRow(
      resourceKey: key,
      status: SyncMetadataStatus.failed,
      attempts: attempts,
      nextRetryAt: retryAt,
      cursorOffset: 0,
    );

void main() {
  late StreamController<List<SyncMetadataRow>> rows;
  late List<String> retried;
  late bool online;
  late SyncRetryScheduler scheduler;

  SyncRetryScheduler build({
    bool Function(String)? handles,
    Future<void> Function(String)? retry,
  }) => SyncRetryScheduler(
    rows: rows.stream,
    isOnline: () => online,
    retry: retry ?? (key) async => retried.add(key),
    handles: handles,
  )..start();

  Duration seconds(int n) => Duration(seconds: n);

  setUp(() {
    rows = StreamController<List<SyncMetadataRow>>();
    retried = [];
    online = true;
  });
  tearDown(() async {
    scheduler.dispose();
    await rows.close();
  });

  test('reintenta cuando llega la hora de nextRetryAt', () {
    fakeAsync((async) {
      scheduler = build();

      rows.add([_failed('catalog', clock.now().add(seconds(4)))]);
      async.elapse(seconds(3));
      expect(retried, isEmpty);

      async.elapse(seconds(1));
      expect(retried, ['catalog']);
    });
  });

  test('respeta una espera larga, como la de un 429 con Retry-After', () {
    fakeAsync((async) {
      scheduler = build();
      rows.add([
        _failed('catalog', clock.now().add(const Duration(minutes: 2))),
      ]);

      async.elapse(seconds(119));
      expect(retried, isEmpty);
      async.elapse(seconds(1));
      expect(retried, ['catalog']);
    });
  });

  test('sin servicio no reintenta a la hora y lo retoma al volver', () {
    fakeAsync((async) {
      scheduler = build();
      online = false;
      rows.add([_failed('catalog', clock.now().add(seconds(2)))]);

      async.elapse(seconds(10));
      expect(retried, isEmpty);

      online = true;
      scheduler.onServiceOnline();
      async.flushMicrotasks();
      expect(retried, ['catalog']);
    });
  });

  test('al volver el servicio no adelanta reintentos que aún no tocan', () {
    fakeAsync((async) {
      scheduler = build();
      rows.add([_failed('catalog', clock.now().add(seconds(30)))]);

      scheduler.onServiceOnline();
      async.elapse(seconds(29));
      expect(retried, isEmpty);
      async.elapse(seconds(1));
      expect(retried, ['catalog']);
    });
  });

  test('sin nextRetryAt (intentos agotados) no reintenta', () {
    fakeAsync((async) {
      scheduler = build();
      rows.add([_failed('catalog', null, attempts: 5)]);

      async.elapse(const Duration(minutes: 5));
      expect(retried, isEmpty);
    });
  });

  test('si el recurso se completa antes de la hora, cancela el reintento', () {
    fakeAsync((async) {
      scheduler = build();
      rows.add([_failed('catalog', clock.now().add(seconds(5)))]);
      async.flushMicrotasks();

      rows.add([
        const SyncMetadataRow(
          resourceKey: 'catalog',
          status: SyncMetadataStatus.completed,
          attempts: 0,
          cursorOffset: 0,
        ),
      ]);
      async.elapse(seconds(10));

      expect(retried, isEmpty);
    });
  });

  test('un nuevo nextRetryAt reemplaza al anterior y no duplica', () {
    fakeAsync((async) {
      scheduler = build();
      final start = clock.now();
      rows.add([_failed('catalog', start.add(seconds(2)))]);
      async.flushMicrotasks();
      rows.add([_failed('catalog', start.add(seconds(8)), attempts: 2)]);

      async.elapse(seconds(5));
      expect(retried, isEmpty);
      async.elapse(seconds(3));
      expect(retried, ['catalog']);
    });
  });

  test('solo reintenta las claves que maneja', () {
    fakeAsync((async) {
      scheduler = build(handles: (key) => key != 'reference');
      final at = clock.now().add(seconds(1));
      rows.add([_failed('reference', at), _failed('detail:25', at)]);

      async.elapse(seconds(2));
      expect(retried, ['detail:25']);
    });
  });

  test('un fallo en el reintento no rompe al planificador', () {
    fakeAsync((async) {
      scheduler = build(retry: (key) async => throw StateError('falla'));
      rows.add([_failed('catalog', clock.now().add(seconds(1)))]);

      expect(() => async.elapse(seconds(2)), returnsNormally);
    });
  });
}
