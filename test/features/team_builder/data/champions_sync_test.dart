import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/sync/backoff_policy.dart';
import 'package:regi_dex/core/sync/sync_coordinator.dart';
import 'package:regi_dex/features/team_builder/data/champions_local_source.dart';
import 'package:regi_dex/features/team_builder/data/champions_remote_source.dart';
import 'package:regi_dex/features/team_builder/data/champions_repository_impl.dart';
import 'package:regi_dex/features/team_builder/data/champions_sync.dart';

import '../../../core/database/database_test_helpers.dart';
import '../../../core/sync/fake_time.dart';
import 'champions_test_data.dart';

/// Ejecuta en línea en vez de un isolate, para controlar el reloj.
Future<R> _inline<R>(FutureOr<R> Function() computation) async => computation();

void main() {
  late AppDatabase db;
  late FakeTime time;
  late SyncCoordinator coordinator;
  late ChampionsLocalSource local;
  late ChampionsSync sync;
  late List<http.Request> requests;
  late List<String> logs;
  late Future<http.Response> Function(http.Request) handler;

  http.Response indexResponse([String dataVersion = '20261127113551736']) =>
      http.Response.bytes(championsIndexBytes(dataVersion: dataVersion), 200);

  setUp(() {
    db = createTestDatabase();
    time = FakeTime();
    coordinator = SyncCoordinator(
      metadata: db.syncMetadataDao,
      backoff: BackoffPolicy(jitter: 0),
      log: (_) {},
    );
    requests = [];
    logs = [];
    handler = (_) async => indexResponse();
    local = ChampionsLocalSource(db);
    sync = ChampionsSync(
      remote: ChampionsRemoteSource(
        endpoint: Uri.parse('https://champions.test'),
        client: MockClient((request) {
          requests.add(request);
          return handler(request);
        }),
        log: (_) {},
      ),
      local: local,
      coordinator: coordinator,
      offload: _inline,
      log: logs.add,
    );
  });
  tearDown(() async {
    coordinator.dispose();
    await db.close();
  });

  group('ChampionsSync', () {
    test('la primera vez descarga y guarda el índice completo', () async {
      final result = await time.run(sync.sync);

      expect(result.fetched, isTrue);
      expect(result.replaced, isTrue);
      expect(requests.single.url.toString(), 'https://champions.test/api');
      final meta = await db.championsDao.getMeta();
      expect(meta?.dataVersion, '20261127113551736');
      expect(meta?.fetchedAt, time.now);
      expect(meta?.defaultSeason, 'Current');
      expect(await db.championsDao.getPokemon(), hasLength(3));
      expect(await db.championsDao.learnableMoveNames('garchomp'), [
        'Double-Edge',
        'Earthquake',
        'Protect',
      ]);
      final entry = await db.syncMetadataDao.getEntry(
        ChampionsSync.resourceKey,
      );
      expect(entry?.status, SyncMetadataStatus.completed);
    });

    test('con la caché vigente no hace ninguna llamada', () async {
      await time.run(sync.sync);
      time.advance(const Duration(hours: 23, minutes: 59));

      final result = await time.run(sync.sync);

      expect(result.fetched, isFalse);
      expect(requests, hasLength(1));
    });

    test('vencida y con el mismo dataVersion solo renueva la fecha', () async {
      await time.run(sync.sync);
      // Una marca propia: si se reescribiera el índice, desaparecería.
      await (db.update(db.championsPokemons)
            ..where((p) => p.showdownId.equals('garchomp')))
          .write(const ChampionsPokemonsCompanion(name: Value('MARCA')));
      time.advance(const Duration(hours: 24));

      final result = await time.run(sync.sync);

      expect(result.fetched, isTrue);
      expect(result.replaced, isFalse);
      expect(requests, hasLength(2));
      final meta = await db.championsDao.getMeta();
      expect(meta?.fetchedAt, time.now);
      final garchomp = (await db.championsDao.getPokemon()).firstWhere(
        (p) => p.showdownId == 'garchomp',
      );
      expect(garchomp.name, 'MARCA');
    });

    test('con otro dataVersion reemplaza los datos', () async {
      await time.run(sync.sync);
      handler = (_) async => http.Response.bytes(
        championsIndexBytes(
          dataVersion: '20261128000000000',
          pokemon: [
            championsPokemonJson(showdownId: 'garchomp', moves: ['Protect']),
          ],
        ),
        200,
      );
      time.advance(const Duration(hours: 25));

      final result = await time.run(sync.sync);

      expect(result.replaced, isTrue);
      expect(
        (await db.championsDao.getMeta())?.dataVersion,
        '20261128000000000',
      );
      expect(await db.championsDao.getPokemon(), hasLength(1));
      expect(await db.championsDao.learnableMoveNames('garchomp'), ['Protect']);
      expect(await db.championsDao.learnableMoveNames('mimikyu'), isEmpty);
    });

    test('force descarga aunque la caché esté vigente', () async {
      await time.run(sync.sync);

      await time.run(() => sync.sync(force: true));

      expect(requests, hasLength(2));
    });

    test(
      'sin red conserva la caché y deja el fallo en sync_metadata',
      () async {
        await time.run(sync.sync);
        handler = (_) async => throw const SocketException('sin red');
        time.advance(const Duration(days: 2));

        await expectLater(time.run(sync.sync), throwsA(isA<NetworkFailure>()));

        expect(await db.championsDao.getPokemon(), hasLength(3));
        expect(
          (await db.championsDao.getMeta())?.dataVersion,
          '20261127113551736',
        );
        final entry = await db.syncMetadataDao.getEntry(
          ChampionsSync.resourceKey,
        );
        expect(entry?.status, SyncMetadataStatus.failed);
        expect(entry?.attempts, 1);
      },
    );

    test('un 429 deja la caché y programa la espera del servicio', () async {
      await time.run(sync.sync);
      handler = (_) async => http.Response('', 429);
      time.advance(const Duration(days: 2));

      await expectLater(time.run(sync.sync), throwsA(isA<RateLimitFailure>()));

      final entry = await db.syncMetadataDao.getEntry(
        ChampionsSync.resourceKey,
      );
      expect(entry?.nextRetryAt, isNotNull);
      expect(await db.championsDao.getPokemon(), hasLength(3));
    });

    test('un índice inválido no toca la caché', () async {
      await time.run(sync.sync);
      handler = (_) async => http.Response('{"dataVersion": "x"}', 200);
      time.advance(const Duration(days: 2));

      await expectLater(time.run(sync.sync), throwsA(isA<ValidationFailure>()));

      expect(await db.championsDao.getPokemon(), hasLength(3));
      expect(
        (await db.championsDao.getMeta())?.dataVersion,
        '20261127113551736',
      );
    });

    test('dos solicitudes a la vez comparten una sola llamada', () async {
      final gate = Completer<void>();
      handler = (_) async {
        await gate.future;
        return indexResponse();
      };

      final first = time.run(sync.sync);
      final second = time.run(sync.sync);
      gate.complete();
      await Future.wait([first, second]);

      expect(requests, hasLength(1));
    });
  });

  group('correspondencia con PokéAPI', () {
    Future<void> seedCatalog() async {
      await seedReference(db);
      await upsertSimplePokemon(db, 445, 'garchomp');
      await upsertSimplePokemon(db, 778, 'mimikyu-disguised');
    }

    test('relaciona por nombre normalizado y por alias', () async {
      await seedCatalog();

      await time.run(sync.sync);

      final rows = {
        for (final row in await db.championsDao.getPokemon())
          row.showdownId: row.pokeapiPokemonId,
      };
      expect(rows['garchomp'], 445);
      expect(rows['mimikyu'], 778);
      // La variante aún no está en el catálogo local.
      expect(rows['raichualola'], isNull);
    });

    test('las variantes se relacionan por pokemon_form', () async {
      await seedCatalog();
      await upsertSimplePokemon(db, 26, 'raichu');
      await db
          .into(db.pokemonForms)
          .insert(
            PokemonFormsCompanion.insert(
              pokemonId: const Value(10100),
              speciesId: 26,
              name: 'raichu-alola',
            ),
          );

      await time.run(sync.sync);

      final alola = (await db.championsDao.getPokemon()).firstWhere(
        (p) => p.showdownId == 'raichualola',
      );
      expect(alola.pokeapiPokemonId, 10100);
    });

    test(
      'si el catálogo llega después, se relaciona al abrir el pool',
      () async {
        await time.run(sync.sync);
        expect(
          (await db.championsDao.getPokemon()).every(
            (p) => p.pokeapiPokemonId == null,
          ),
          isTrue,
        );
        await seedCatalog();
        final repository = ChampionsRepositoryImpl(local: local, sync: sync);

        final pool = await repository.watchPool().first;

        expect({
          for (final p in pool) p.showdownId: p.pokeapiPokemonId,
        }, containsPair('garchomp', 445));
      },
    );

    test('relaciona los movimientos por nombre normalizado', () async {
      await seedCatalog();
      await db.referenceDao.upsertReferenceData(
        moves: [
          MovesCompanion.insert(id: const Value(89), name: 'earthquake'),
          MovesCompanion.insert(id: const Value(38), name: 'double-edge'),
        ],
      );

      await time.run(sync.sync);

      final moves = {
        for (final row in await db.championsDao.getLearnableMoves())
          '${row.showdownId}/${row.moveName}': row.pokeapiMoveId,
      };
      expect(moves['garchomp/Earthquake'], 89);
      expect(moves['garchomp/Double-Edge'], 38);
      expect(moves['garchomp/Protect'], isNull);
    });
  });

  group('contraste con el version group champions (32)', () {
    test('avisa si el grupo 32 aún no está en la referencia', () async {
      await time.run(sync.sync);

      expect(logs.single, contains('version group champions (32)'));
      final check = await local.checkLearnsets();
      expect(check.versionGroupKnown, isFalse);
    });

    test('cuenta los movimientos de Champions que PokéAPI no lista', () async {
      await seedReference(db);
      await upsertSimplePokemon(db, 445, 'garchomp');
      await db.referenceDao.upsertReferenceData(
        versionGroups: [
          VersionGroupsCompanion.insert(id: const Value(32), name: 'champions'),
        ],
        moves: [
          MovesCompanion.insert(id: const Value(89), name: 'earthquake'),
          MovesCompanion.insert(id: const Value(182), name: 'protect'),
          MovesCompanion.insert(id: const Value(38), name: 'double-edge'),
        ],
      );
      // PokéAPI lista Terremoto y Protección para Garchomp en el grupo 32, pero
      // no Doble Filo.
      for (final moveId in [89, 182]) {
        await db
            .into(db.pokemonMoves)
            .insert(
              PokemonMovesCompanion.insert(
                pokemonId: 445,
                moveId: moveId,
                versionGroupId: 32,
                learnMethodId: 1,
              ),
            );
      }

      await time.run(sync.sync);

      final check = await local.checkLearnsets();
      expect(check.versionGroupKnown, isTrue);
      expect(check.pokemonChecked, 1);
      expect(check.movesMissingInPokeApi, 1);
      expect(logs.single, contains('1 movimientos de Champions'));
    });
  });

  group('ChampionsRepositoryImpl', () {
    test('expone el pool, la versión de los datos y el aprendizaje', () async {
      final repository = ChampionsRepositoryImpl(local: local, sync: sync);
      expect(await repository.watchInfo().first, isNull);

      await time.run(() => repository.refresh());

      final pool = await repository.watchPool().first;
      expect(pool.map((p) => p.showdownId), [
        'garchomp',
        'mimikyu',
        'raichualola',
      ]);
      final garchomp = pool.firstWhere((p) => p.showdownId == 'garchomp');
      expect(garchomp.types, ['Dragon', 'Ground']);
      expect(garchomp.allAbilities, ['Sand Veil', 'Rough Skin']);
      expect(garchomp.stats.hp, 183);
      expect(pool.firstWhere((p) => p.showdownId == 'mimikyu').allAbilities, [
        'Disguise',
        'Disguise',
      ]);

      final info = await repository.watchInfo().first;
      expect(info?.dataVersion, '20261127113551736');
      // Drift guarda la fecha en segundos.
      expect(
        info?.generatedAt.isAtSameMomentAs(
          DateTime.utc(2026, 11, 27, 11, 35, 51),
        ),
        isTrue,
      );
      expect(await repository.learnableMoves('raichualola'), ['Protect']);
    });

    test(
      'con la caché cargada funciona aunque el servicio esté caído',
      () async {
        final repository = ChampionsRepositoryImpl(local: local, sync: sync);
        await time.run(() => repository.refresh());
        handler = (_) async => http.Response('', 503);
        time.advance(const Duration(days: 3));

        await expectLater(
          time.run(() => repository.refresh()),
          throwsA(isA<ServiceUnavailableFailure>()),
        );

        expect(await repository.watchPool().first, hasLength(3));
        expect(await repository.watchInfo().first, isNotNull);
      },
    );
  });
}
