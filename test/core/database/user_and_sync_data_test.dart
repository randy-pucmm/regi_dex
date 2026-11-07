import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';

import 'database_test_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  group('favoritos', () {
    test('agregar dos veces no duplica ni cambia la fecha de alta', () async {
      await db.favoriteDao.addFavorite(25, createdAt: DateTime(2026, 11, 3, 8));
      await db.favoriteDao.addFavorite(25, createdAt: DateTime(2026, 11, 3, 9));

      final rows = await db.favoriteDao.watchFavorites().first;
      expect(rows, hasLength(1));
      expect(rows.single.createdAt, DateTime(2026, 11, 3, 8));
    });

    test('se pueden guardar sin que el Pokémon esté en el catálogo', () async {
      await db.favoriteDao.addFavorite(1025);
      expect(await db.favoriteDao.isFavorite(1025), isTrue);
      expect(await db.favoriteDao.isFavorite(1), isFalse);
    });

    test('watchFavoriteIds emite al agregar y quitar', () async {
      final expectation = expectLater(
        db.favoriteDao.watchFavoriteIds(),
        emitsInOrder([
          emits(isEmpty),
          emitsThrough({4}),
          emitsThrough(isEmpty),
        ]),
      );
      await pumpEventQueue();

      await db.favoriteDao.addFavorite(4);
      await db.favoriteDao.removeFavorite(4);
      await expectation;
    });

    test('el más reciente aparece primero', () async {
      await db.favoriteDao.addFavorite(1, createdAt: DateTime(2026, 11, 3, 8));
      await db.favoriteDao.addFavorite(2, createdAt: DateTime(2026, 11, 3, 9));

      final rows = await db.favoriteDao.watchFavorites().first;
      expect([for (final row in rows) row.pokemonId], [2, 1]);
    });
  });

  group('preferencias', () {
    test('guarda, reemplaza y borra un valor', () async {
      expect(await db.preferenceDao.getValue('theme'), isNull);

      await db.preferenceDao.setValue('theme', 'regice');
      await db.preferenceDao.setValue('theme', 'regirock');
      expect(await db.preferenceDao.getValue('theme'), 'regirock');
      expect(await rowCount(db, 'user_preference'), 1);

      await db.preferenceDao.remove('theme');
      expect(await db.preferenceDao.getValue('theme'), isNull);
    });

    test('watchValue emite los cambios', () async {
      final expectation = expectLater(
        db.preferenceDao.watchValue('locale'),
        emitsInOrder([isNull, emitsThrough('es'), emitsThrough('en')]),
      );
      await pumpEventQueue();

      await db.preferenceDao.setValue('locale', 'es');
      await db.preferenceDao.setValue('locale', 'en');
      await expectation;
    });
  });

  group('sync_metadata', () {
    SyncMetadataEntriesCompanion entry(String status, {int attempts = 0}) =>
        SyncMetadataEntriesCompanion.insert(
          resourceKey: 'catalog',
          status: status,
          attempts: Value(attempts),
        );

    test('un upsert repetido deja una sola fila por recurso', () async {
      await db.syncMetadataDao.upsert(entry('syncing'));
      await db.syncMetadataDao.upsert(entry('failed', attempts: 2));

      expect(await rowCount(db, 'sync_metadata'), 1);
      final row = await db.syncMetadataDao.getEntry('catalog');
      expect(row!.status, 'failed');
      expect(row.attempts, 2);
      expect(row.cursorOffset, 0);
    });

    test('advanceCursor solo cambia el cursor de ese recurso', () async {
      await db.syncMetadataDao.upsert(entry('syncing', attempts: 1));
      await db.syncMetadataDao.upsert(
        SyncMetadataEntriesCompanion.insert(
          resourceKey: 'reference',
          status: 'completed',
        ),
      );

      expect(await db.syncMetadataDao.advanceCursor('catalog', 400), isTrue);

      final catalog = await db.syncMetadataDao.getEntry('catalog');
      expect(catalog!.cursorOffset, 400);
      expect(catalog.status, 'syncing');
      expect(catalog.attempts, 1);
      expect((await db.syncMetadataDao.getEntry('reference'))!.cursorOffset, 0);
    });

    test('advanceCursor no crea filas: devuelve false sin fila', () async {
      expect(await db.syncMetadataDao.advanceCursor('catalog', 200), isFalse);
      expect(await rowCount(db, 'sync_metadata'), 0);
    });

    test('getEntry devuelve null si el recurso nunca se sincronizó', () async {
      expect(await db.syncMetadataDao.getEntry('reference'), isNull);
    });

    test('watchEntry emite el cambio de estado', () async {
      final expectation = expectLater(
        db.syncMetadataDao.watchEntry('catalog').map((row) => row?.status),
        emitsInOrder([
          isNull,
          emitsThrough('syncing'),
          emitsThrough('completed'),
        ]),
      );
      await pumpEventQueue();

      await db.syncMetadataDao.upsert(entry('syncing'));
      await db.syncMetadataDao.upsert(entry('completed'));
      await expectation;
    });
  });

  group('api_call_log', () {
    final t0 = DateTime(2026, 11, 3, 10);

    test('cuenta las llamadas dentro de la ventana', () async {
      await db.apiCallLogDao.record('HealthCheck', calledAt: t0);
      await db.apiCallLogDao.record(
        'GetPokemonPage',
        calledAt: t0.add(const Duration(minutes: 30)),
      );
      await db.apiCallLogDao.record(
        'GetPokemonPage',
        calledAt: t0.add(const Duration(minutes: 61)),
      );

      final since = t0
          .add(const Duration(minutes: 61))
          .subtract(const Duration(minutes: 60));
      expect(await db.apiCallLogDao.countSince(since), 2);
      expect(
        await db.apiCallLogDao.oldestSince(since),
        t0.add(const Duration(minutes: 30)),
      );
    });

    test('oldestSince es null sin llamadas en la ventana', () async {
      expect(await db.apiCallLogDao.oldestSince(t0), isNull);
      expect(await db.apiCallLogDao.countSince(t0), 0);
    });

    test('guarda el estado HTTP al terminar la llamada', () async {
      final id = await db.apiCallLogDao.record('HealthCheck', calledAt: t0);
      await db.apiCallLogDao.setHttpStatus(id, 200);

      final row = await db.select(db.apiCallLogs).getSingle();
      expect(row.httpStatus, 200);
    });

    test('purgeBefore borra solo las llamadas anteriores al corte', () async {
      await db.apiCallLogDao.record('A', calledAt: t0);
      await db.apiCallLogDao.record(
        'B',
        calledAt: t0.add(const Duration(hours: 2)),
      );

      final purged = await db.apiCallLogDao.purgeBefore(
        t0.add(const Duration(hours: 1)),
      );

      expect(purged, 1);
      expect(await rowCount(db, 'api_call_log'), 1);
    });
  });
}
