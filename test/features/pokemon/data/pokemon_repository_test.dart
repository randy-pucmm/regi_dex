import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/sync/backoff_policy.dart';
import 'package:regi_dex/core/sync/sync_coordinator.dart';
import 'package:regi_dex/features/pokemon/data/catalog_local_source.dart';
import 'package:regi_dex/features/pokemon/data/catalog_sync.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_repository_impl.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_query.dart';

import '../../../core/database/database_test_helpers.dart';
import '../../../core/sync/fake_time.dart';
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
}
