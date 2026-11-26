import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/sync/api_budget.dart';
import 'package:regi_dex/core/sync/sync_coordinator.dart';
import 'package:regi_dex/features/pokemon/data/catalog_local_source.dart';
import 'package:regi_dex/features/pokemon/data/integrity_checker.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_mapper.dart';

import '../../../core/database/database_test_helpers.dart';
import 'catalog_test_data.dart';
import 'fake_pokemon_remote.dart';

final _syncedAt = DateTime(2026, 11, 26, 9);

void main() {
  late AppDatabase db;
  late CatalogLocalSource local;
  late FakePokemonRemote remote;
  late ApiBudget budget;
  late List<String> logs;
  var online = true;

  IntegrityChecker build({int batchSize = 200, int reserve = 10}) =>
      IntegrityChecker(
        remote: remote,
        local: local,
        metadata: db.syncMetadataDao,
        budget: budget,
        isOnline: () => online,
        batchSize: batchSize,
        reserve: reserve,
        offload: <R>(computation) async => computation(),
        log: logs.add,
      );

  Future<void> seed(int count) => local.savePokemon(
    mapPokemonPage({
      'pokemon': [for (var id = 1; id <= count; id++) syntheticPokemon(id)],
    }, _syncedAt),
  );

  Future<String> nameOf(int id) async =>
      (await db.catalogDao.getPokemon(id))!.name;

  Future<void> rename(int id, String name) => (db.update(
    db.pokemons,
  )..where((p) => p.id.equals(id))).write(PokemonsCompanion(name: Value(name)));

  Future<SyncMetadataRow?> entry() =>
      db.syncMetadataDao.getEntry(IntegrityChecker.resourceKey);

  setUp(() async {
    online = true;
    logs = [];
    db = createTestDatabase();
    local = CatalogLocalSource(db);
    remote = FakePokemonRemote();
    budget = ApiBudget(log: db.apiCallLogDao);
    await local.saveReference(mapReferenceData(syntheticReference()));
  });
  tearDown(() => db.close());

  group('restauración (OF-19)', () {
    test('sin diferencias verifica y no cambia nada', () async {
      await seed(5);

      final report = await build().verify();

      expect(report.isSuccess, isTrue);
      expect(report.checked, 5);
      expect(report.restored, isEmpty);
      expect(remote.idBatches, [
        [1, 2, 3, 4, 5],
      ]);
      expect(logs.single, contains('verificados 5'));
      expect(logs.single, contains('sin diferencias'));
    });

    test('un nombre editado se restaura solo (PA-16)', () async {
      await seed(5);
      await rename(3, 'hackeado');

      final report = await build().verify();

      expect(report.restored, [3]);
      expect(await nameOf(3), 'pokemon-3');
      expect(await nameOf(2), 'pokemon-2');
      expect(logs.single, contains('restaurados 1 (ids 3)'));
      final hashes = await local.contentHashes();
      expect(hashes[3]!.stored, hashes[3]!.computed);
    });

    test('un stat alterado y un tipo borrado también se restauran', () async {
      await seed(5);
      await (db.update(db.pokemonStats)
            ..where((s) => s.pokemonId.equals(2) & s.statId.equals(1)))
          .write(const PokemonStatsCompanion(baseStat: Value(255)));
      await (db.delete(
        db.pokemonTypes,
      )..where((t) => t.pokemonId.equals(4))).go();

      final report = await build().verify();

      expect(report.restored, unorderedEquals([2, 4]));
      expect((await db.catalogDao.statsOf(2)).first.baseStat, 41);
      expect(await db.catalogDao.typesOf(4), isNotEmpty);
    });

    test('si solo se editó el content_hash guardado, se corrige', () async {
      await seed(3);
      await (db.update(db.pokemons)..where((p) => p.id.equals(1))).write(
        const PokemonsCompanion(contentHash: Value('basura')),
      );

      final report = await build().verify();

      expect(report.restored, [1]);
      final hashes = await local.contentHashes(ids: [1]);
      expect(hashes[1]!.stored, hashes[1]!.computed);
    });

    test(
      'si el remoto cambió, el remoto gana aunque lo local esté intacto',
      () async {
        await seed(3);
        remote.tamperByIds = (page) {
          ((page['pokemon'] as List).first as Map<String, dynamic>)['name'] =
              'nuevo-nombre';
        };

        final report = await build().verify();

        expect(report.restored, [1]);
        expect(await nameOf(1), 'nuevo-nombre');
      },
    );

    test('conserva el detalle ya descargado (movimientos y detalle)', () async {
      await seed(2);
      await rename(1, 'hackeado');
      final before = await catalogCounts(db);

      await build().verify();

      final after = await catalogCounts(db);
      expect(after, before);
    });
  });

  group('datos del usuario (OF-21)', () {
    test('favoritos y preferencias quedan intactos tras restaurar', () async {
      await seed(5);
      await db
          .into(db.favorites)
          .insert(
            FavoritesCompanion.insert(
              pokemonId: const Value(3),
              createdAt: _syncedAt,
            ),
          );
      await db.preferenceDao.setValue('catalog_query', '{"x":1}');
      await rename(3, 'hackeado');

      await build().verify();

      expect(await nameOf(3), 'pokemon-3');
      expect(await rowCount(db, 'favorite'), 1);
      expect(await db.preferenceDao.getValue('catalog_query'), '{"x":1}');
    });
  });

  group('lote rotativo', () {
    test('recorre el catálogo por lotes y da la vuelta', () async {
      await seed(5);
      final checker = build(batchSize: 2);

      await checker.verify();
      await checker.verify();
      await checker.verify();
      await checker.verify();

      expect(remote.idBatches, [
        [1, 2],
        [3, 4],
        [5],
        [1, 2],
      ]);
    });

    test('guarda el último id verificado en sync_metadata', () async {
      await seed(5);

      await build(batchSize: 2).verify();

      final row = await entry();
      expect(row?.status, SyncMetadataStatus.completed);
      expect(row?.cursorOffset, 2);
      expect(row?.lastSuccessAt, isNotNull);
    });

    test(
      'los marcados van primero y completan el lote con el recorrido',
      () async {
        await seed(6);
        await rename(5, 'hackeado');

        await build(batchSize: 3).verify();

        expect(remote.idBatches.single, [5, 1, 2]);
      },
    );

    test(
      'con más marcados que el tamaño del lote no avanza el recorrido',
      () async {
        await seed(6);
        for (final id in [3, 4, 5]) {
          await rename(id, 'hackeado-$id');
        }

        await build(batchSize: 2).verify();

        expect(remote.idBatches.single, [3, 4]);
        expect((await entry())?.cursorOffset, 0);
      },
    );

    test('un lote real nunca pasa de 200 ids', () async {
      await seed(450);

      await build().verify();

      expect(remote.idBatches.single, hasLength(200));
    });
  });

  group('presupuesto y servicio', () {
    test('sin servicio no hace ninguna llamada', () async {
      await seed(3);
      await rename(2, 'hackeado');
      online = false;

      final report = await build().verify();

      expect(report.skipped, isTrue);
      expect(remote.idBatches, isEmpty);
      expect(await nameOf(2), 'hackeado');
    });

    test('con el catálogo vacío no llama', () async {
      final report = await build().verify();

      expect(report.skipped, isTrue);
      expect(remote.idBatches, isEmpty);
    });

    test(
      'sin cupo sobre la reserva omite el recorrido pero no los marcados',
      () async {
        await seed(5);
        budget = ApiBudget(log: db.apiCallLogDao, limit: 12);
        for (var i = 0; i < 3; i++) {
          await db.apiCallLogDao.record('x', calledAt: clock.now());
        }

        final none = await build().verify();
        expect(none.skipped, isTrue);
        expect(remote.idBatches, isEmpty);

        await rename(4, 'hackeado');
        await build().verify();

        expect(remote.idBatches.single, [4]);
        expect(await nameOf(4), 'pokemon-4');
      },
    );

    test('dos verificaciones a la vez comparten una sola llamada', () async {
      await seed(5);
      final checker = build();

      final results = await Future.wait([checker.verify(), checker.verify()]);

      expect(remote.idBatches, hasLength(1));
      expect(identical(results[0], results[1]), isTrue);
    });
  });

  group('fallos', () {
    test('un fallo de red no lanza, no cambia nada y se registra', () async {
      await seed(3);
      await rename(2, 'hackeado');
      remote.failByIds = true;

      final report = await build().verify();

      expect(report.error, isA<NetworkFailure>());
      expect(await nameOf(2), 'hackeado');
      final row = await entry();
      expect(row?.status, SyncMetadataStatus.failed);
      expect(row?.cursorOffset, 0);
      expect(logs.single, contains('[Integridad] falló'));
    });

    test('tras el fallo, el siguiente intento restaura', () async {
      await seed(3);
      await rename(2, 'hackeado');
      remote.failByIds = true;
      final checker = build();
      await checker.verify();

      remote.failByIds = false;
      final report = await checker.verify();

      expect(report.restored, [2]);
      expect(await nameOf(2), 'pokemon-2');
      expect((await entry())?.status, SyncMetadataStatus.completed);
    });

    test('una respuesta inválida descarta el lote sin tocar la base', () async {
      await seed(3);
      await rename(2, 'hackeado');
      remote.tamperByIds = (page) {
        ((page['pokemon'] as List).first as Map<String, dynamic>).remove(
          'name',
        );
      };

      final report = await build().verify();

      expect(report.error, isNotNull);
      expect(await nameOf(2), 'hackeado');
      expect(await nameOf(1), 'pokemon-1');
    });
  });

  group('al abrir un detalle', () {
    test('compara ese Pokémon con el remoto una sola vez por sesión', () async {
      await seed(5);
      final checker = build();

      final first = await checker.verifyPokemon(3);
      final second = await checker.verifyPokemon(3);

      expect(first.checked, 1);
      expect(second.skipped, isTrue);
      expect(remote.idBatches, [
        [3],
      ]);
    });

    test(
      'si su hash local no coincide, lo restaura aunque ya se haya visto',
      () async {
        await seed(5);
        final checker = build();
        await checker.verifyPokemon(3);
        await rename(3, 'hackeado');

        final report = await checker.verifyPokemon(3);

        expect(report.restored, [3]);
        expect(await nameOf(3), 'pokemon-3');
      },
    );

    test('un Pokémon que no está en el catálogo no genera llamadas', () async {
      await seed(2);

      final report = await build().verifyPokemon(99);

      expect(report.skipped, isTrue);
      expect(remote.idBatches, isEmpty);
    });

    test('sin servicio no llama', () async {
      await seed(2);
      online = false;

      await build().verifyPokemon(1);

      expect(remote.idBatches, isEmpty);
    });
  });
}
