import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/sync/backoff_policy.dart';
import 'package:regi_dex/core/sync/sync_coordinator.dart';
import 'package:regi_dex/features/pokemon/data/catalog_local_source.dart';
import 'package:regi_dex/features/pokemon/data/catalog_sync.dart';
import 'package:regi_dex/features/pokemon/data/detail_sync.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_mapper.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_repository_impl.dart';
import 'package:regi_dex/features/pokemon/data/remote_search.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_query.dart';

import '../../../core/database/database_test_helpers.dart';
import '../../../core/sync/fake_time.dart';
import 'catalog_test_data.dart';
import 'fake_pokemon_remote.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeTime time;
  late SyncCoordinator coordinator;
  late FakePokemonRemote remote;
  late PokemonRepositoryImpl repository;

  PokemonRepositoryImpl buildRepository(
    FakePokemonRemote source,
    SyncCoordinator using,
  ) => PokemonRepositoryImpl(
    catalog: db.catalogDao,
    coordinator: using,
    sync: CatalogSync(
      remote: source,
      local: CatalogLocalSource(db),
      coordinator: using,
    ),
    detail: DetailSync(
      remote: source,
      local: CatalogLocalSource(db),
      coordinator: using,
    ),
    search: RemoteSearch(remote: source, local: CatalogLocalSource(db)),
  );

  setUp(() {
    db = createTestDatabase();
    time = FakeTime();
    coordinator = SyncCoordinator(
      metadata: db.syncMetadataDao,
      backoff: BackoffPolicy(jitter: 0),
    );
    remote = FakePokemonRemote();
    repository = buildRepository(remote, coordinator);
  });
  tearDown(() async {
    coordinator.dispose();
    await db.close();
  });

  Future<List<Pokemon>> current() =>
      repository.watchPokemon(const PokemonQuery()).first;

  group('watchPokemon', () {
    test('con la base vacía emite una lista vacía', () async {
      expect(await current(), isEmpty);
    });

    test('devuelve entidades de dominio con sus tipos', () async {
      await time.run(repository.refresh);

      final all = await current();
      expect(all, hasLength(450));
      expect(all.map((p) => p.id).take(3), [1, 2, 3]);
      expect(
        all.first,
        const Pokemon(
          id: 1,
          name: 'pokemon-1',
          baseStatTotal: 261,
          spriteUrl: 'https://img.test/1.png',
          artworkUrl: 'https://img.test/a/1.png',
          types: [PokemonTypeRef(id: 2, name: 'type-2', nameEs: 'Tipo 2')],
        ),
      );
    });

    test('emite la lista creciente a medida que llegan los lotes', () async {
      final sizes = <int>[];
      final subscription = repository
          .watchPokemon(const PokemonQuery())
          .listen((list) => sizes.add(list.length));
      await pumpEventQueue();

      await time.run(repository.refresh);
      await pumpEventQueue();
      await subscription.cancel();

      expect(sizes, [0, 200, 400, 450]);
    });

    test(
      'sin red sigue sirviendo lo guardado (offline tras reinicio)',
      () async {
        await time.run(repository.refresh);

        // «Reinicio»: otro repositorio sobre la misma BD, con la red caída.
        final offline = FakePokemonRemote()..failAtOffset = 0;
        final restarted = SyncCoordinator(metadata: db.syncMetadataDao);
        addTearDown(restarted.dispose);
        final reopened = buildRepository(offline, restarted);

        final list = await reopened.watchPokemon(const PokemonQuery()).first;

        expect(list, hasLength(450));
        expect(offline.pageOffsets, isEmpty, reason: 'no necesita la red');
      },
    );
  });

  group('watchPokemon con búsqueda (PA-17)', () {
    Future<List<String>> names(String search) async => [
      for (final p
          in await repository.watchPokemon(PokemonQuery(search: search)).first)
        p.name,
    ];

    setUp(() async {
      await seedReference(db);
      await seedSearchCatalog(db);
    });

    test('«377» devuelve Regirock', () async {
      expect(await names('377'), ['regirock']);
    });

    test('«#0378» devuelve Regice', () async {
      expect(await names('#0378'), ['regice']);
    });

    test('«25», «#025» y «pika» devuelven Pikachu', () async {
      expect(await names('25'), ['pikachu']);
      expect(await names('#025'), ['pikachu']);
      expect(await names('pika'), ['pikachu']);
    });

    test('«reg» devuelve los dos Regis por número', () async {
      expect(await names('reg'), ['regirock', 'regice']);
    });

    test(
      'una búsqueda sin coincidencias queda vacía, sin llamar a la red',
      () async {
        expect(await names('mewtwo'), isEmpty);
        expect(remote.pageOffsets, isEmpty);
        expect(remote.referenceCalls, 0);
      },
    );

    test('la búsqueda en blanco devuelve todo', () async {
      expect(await names('   '), hasLength(5));
    });
  });

  group('watchPokemon con filtros y orden (PA-18)', () {
    Future<List<String>> names(PokemonQuery query) async => [
      for (final p in await repository.watchPokemon(query).first) p.name,
    ];

    setUp(() => seedFilterCatalog(db));

    test('grupo huevo Mineral y tipo Roca devuelve Geodude y Golem', () async {
      expect(await names(const PokemonQuery(eggGroups: {3}, types: {6})), [
        'geodude',
        'golem',
      ]);
    });

    test('el orden por total base descendente llega a la lista', () async {
      final result = await names(
        const PokemonQuery(
          types: {6},
          sort: PokemonSort.baseTotal,
          descending: true,
        ),
      );

      expect(result, ['regirock', 'golem', 'geodude']);
    });

    test('filtros, orden y búsqueda a la vez', () async {
      final result = await names(
        const PokemonQuery(
          search: 'g',
          generations: {1},
          sort: PokemonSort.name,
          descending: true,
        ),
      );

      expect(result, ['golem', 'geodude']);
    });

    test('los tipos de cada resultado siguen completos', () async {
      final result = await repository
          .watchPokemon(const PokemonQuery(types: {5}))
          .first;

      expect(result.first.types.map((t) => t.name), ['rock', 'ground']);
    });
  });

  group('searchRemote', () {
    // Las claves foráneas del Pokémon exigen la referencia ya descargada.
    setUp(
      () =>
          CatalogLocalSource(db)
              .saveReference(mapReferenceData(syntheticReference())),
    );

    test('guarda lo encontrado y watchPokemon lo emite', () async {
      remote.searchResultIds = [377];

      final saved = await repository.searchRemote('#0377');

      expect(saved, 1);
      expect(remote.searches, ['numero:377']);
      final found = await repository
          .watchPokemon(const PokemonQuery(search: '377'))
          .first;
      expect(found.map((p) => p.id), [377]);
    });

    test('una búsqueda en blanco no llama a la red', () async {
      expect(await repository.searchRemote('  '), 0);
      expect(remote.searches, isEmpty);
    });

    test('si falla propaga el Failure y la base sigue vacía', () async {
      remote.failSearch = true;

      await expectLater(
        repository.searchRemote('pika'),
        throwsA(isA<NetworkFailure>()),
      );

      expect(await current(), isEmpty);
    });
  });

  group('refresh', () {
    test('sincroniza el catálogo y deja la sync completada', () async {
      await time.run(repository.refresh);

      expect(await db.catalogDao.countPokemon(), 450);
      final entry = await db.syncMetadataDao.getEntry(CatalogSync.resourceKey);
      expect(entry!.status, SyncMetadataStatus.completed);
    });

    test('dos refresh simultáneos hacen una sola pasada', () async {
      await time.run(
        () => Future.wait([repository.refresh(), repository.refresh()]),
      );

      expect(remote.pageOffsets, [0, 200, 400]);
      expect(remote.referenceCalls, 1);
    });

    test('si falla propaga el Failure y conserva lo ya guardado', () async {
      remote.failAtOffset = 400;

      await expectLater(
        time.run(repository.refresh),
        throwsA(isA<NetworkFailure>()),
      );

      expect(await current(), hasLength(400));
      final entry = await db.syncMetadataDao.getEntry(CatalogSync.resourceKey);
      expect(entry!.status, SyncMetadataStatus.failed);
    });

    test('tras un fallo, el siguiente refresh reanuda donde quedó', () async {
      remote.failAtOffset = 200;
      await expectLater(
        time.run(repository.refresh),
        throwsA(isA<NetworkFailure>()),
      );

      remote
        ..failAtOffset = null
        ..pageOffsets.clear();
      await time.run(repository.refresh);

      expect(remote.pageOffsets, [200, 400]);
      expect(await current(), hasLength(450));
    });
  });

  group('syncDetail', () {
    test('descarga el detalle una sola vez mientras está vigente', () async {
      await time.run(repository.refresh);

      await time.run(() => repository.syncDetail(25));
      await time.run(() => repository.syncDetail(25));

      expect(remote.detailIds, [25]);
      final pokemon = (await db.catalogDao.getPokemon(25))!;
      expect(pokemon.detailSyncedAt, time.now);
      final entry = await db.syncMetadataDao.getEntry('detail:25');
      expect(entry!.status, SyncMetadataStatus.completed);
    });

    test('si falla propaga el Failure y no toca el catálogo', () async {
      await time.run(repository.refresh);
      remote.failDetail = true;

      await expectLater(
        time.run(() => repository.syncDetail(25)),
        throwsA(isA<NetworkFailure>()),
      );

      expect(await current(), hasLength(450));
      expect((await db.catalogDao.getPokemon(25))!.detailSyncedAt, isNull);
    });
  });
}
