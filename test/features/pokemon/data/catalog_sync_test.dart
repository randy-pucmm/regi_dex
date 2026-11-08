import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/network/operation_loader.dart';
import 'package:regi_dex/core/network/poke_api_client.dart';
import 'package:regi_dex/core/sync/api_budget.dart';
import 'package:regi_dex/core/sync/backoff_policy.dart';
import 'package:regi_dex/core/sync/sync_coordinator.dart';
import 'package:regi_dex/features/pokemon/data/catalog_local_source.dart';
import 'package:regi_dex/features/pokemon/data/catalog_sync.dart';
import 'package:regi_dex/features/pokemon/data/content_hash.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_remote_source.dart';

import '../../../core/database/database_test_helpers.dart';
import '../../../core/sync/fake_time.dart';
import 'catalog_test_data.dart';
import 'fake_pokemon_remote.dart';

/// Quita el nombre del Pokémon [id] de la página, si está en ella.
void Function(Map<String, dynamic>) _removeName(int id) => (page) {
  for (final item in page['pokemon'] as List<dynamic>) {
    final json = item as Map<String, dynamic>;
    if (json['id'] == id) json.remove('name');
  }
};

/// Apunta el primer tipo del Pokémon [id] a un tipo que no existe (rompe la FK).
void Function(Map<String, dynamic>) _breakTypeFk(int id) => (page) {
  for (final item in page['pokemon'] as List<dynamic>) {
    final json = item as Map<String, dynamic>;
    if (json['id'] == id) {
      ((json['pokemontypes'] as List<dynamic>).first
              as Map<String, dynamic>)['type_id'] =
          999;
    }
  }
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  CatalogSync syncWith(
    PokemonRemoteSource remote, {
    int pageSize = 200,
    SyncCoordinator? using,
  }) => CatalogSync(
    remote: remote,
    local: CatalogLocalSource(db),
    coordinator: using ?? coordinator,
    pageSize: pageSize,
  );

  /// Una pasada completa a través del coordinador, como la dispara el repositorio.
  Future<void> runSync(CatalogSync sync, {SyncCoordinator? using}) => time.run(
    () =>
        (using ?? coordinator).run<void>(CatalogSync.resourceKey, sync.execute),
  );

  Future<SyncMetadataRow> metadataOf(String key) async =>
      (await db.syncMetadataDao.getEntry(key))!;

  group('pasada completa', () {
    test('descarga la referencia y todo el catálogo en lotes', () async {
      final remote = FakePokemonRemote();

      await runSync(syncWith(remote));

      expect(remote.referenceCalls, 1);
      expect(remote.pageOffsets, [0, 200, 400]);
      final counts = await catalogCounts(db);
      expect(counts['pokemon'], 450);
      expect(counts['species'], 450);
      expect(counts['type'], syntheticTypeCount);
      expect(counts['pokemon_stat'], 450 * 6);
      final catalog = await metadataOf('catalog');
      expect(catalog.status, SyncMetadataStatus.completed);
      expect(catalog.cursorOffset, 0, reason: 'la pasada terminó');
      expect((await metadataOf('reference')).status, 'completed');
    });

    test('guarda el nombre de la especie y el content_hash', () async {
      await runSync(syncWith(FakePokemonRemote()));

      final species = await (db.select(
        db.species,
      )..where((s) => s.id.equals(7))).getSingle();
      expect(species.name, 'species-7');

      final pokemon = (await db.catalogDao.getPokemon(7))!;
      final types = await db.select(db.pokemonTypes).get();
      final abilities = await db.select(db.pokemonAbilities).get();
      final stats = await db.select(db.pokemonStats).get();
      expect(
        pokemon.contentHash,
        computeContentHash(
          name: pokemon.name,
          height: pokemon.height,
          weight: pokemon.weight,
          types: [
            for (final t in types.where((t) => t.pokemonId == 7))
              (slot: t.slot, typeId: t.typeId),
          ],
          abilities: [
            for (final a in abilities.where((a) => a.pokemonId == 7))
              (slot: a.slot, abilityId: a.abilityId, isHidden: a.isHidden),
          ],
          stats: [
            for (final s in stats.where((s) => s.pokemonId == 7))
              (statId: s.statId, baseStat: s.baseStat),
          ],
        ),
      );
    });

    test('con páginas chicas la última sale corta', () async {
      final remote = FakePokemonRemote(total: 5);

      await runSync(syncWith(remote, pageSize: 2));

      expect(remote.pageOffsets, [0, 2, 4]);
      expect(await db.catalogDao.countPokemon(), 5);
      expect((await metadataOf('catalog')).cursorOffset, 0);
    });

    test(
      'con un total múltiplo del lote cierra con una página vacía',
      () async {
        final remote = FakePokemonRemote(total: 4);

        await runSync(syncWith(remote, pageSize: 2));

        expect(remote.pageOffsets, [0, 2, 4]);
        expect(await db.catalogDao.countPokemon(), 4);
        expect((await metadataOf('catalog')).cursorOffset, 0);
      },
    );
  });

  group('idempotencia (PA-13)', () {
    test('tres sincronizaciones seguidas no cambian los conteos', () async {
      final remote = FakePokemonRemote();
      final sync = syncWith(remote);

      await runSync(sync);
      final first = await catalogCounts(db);
      await runSync(sync);
      final second = await catalogCounts(db);
      await runSync(sync);
      final third = await catalogCounts(db);

      expect(second, first);
      expect(third, first);
      expect(first['pokemon'], 450);
      expect(remote.pageOffsets, [
        0,
        200,
        400,
        0,
        200,
        400,
        0,
        200,
        400,
      ], reason: 'cada pasada empieza de cero');
    });
  });

  group('referencia', () {
    test('no se vuelve a pedir mientras está vigente', () async {
      final remote = FakePokemonRemote();
      final sync = syncWith(remote);

      await runSync(sync);
      time.advance(const Duration(days: 29));
      await runSync(sync);

      expect(remote.referenceCalls, 1);
    });

    test('se pide de nuevo al vencer los 30 días', () async {
      final remote = FakePokemonRemote();
      final sync = syncWith(remote);

      await runSync(sync);
      time.advance(const Duration(days: 31));
      await runSync(sync);

      expect(remote.referenceCalls, 2);
    });

    test('un fallo en la referencia no pide ninguna página', () async {
      final remote = FakePokemonRemote();
      final failing = _FailingReference(remote);

      await expectLater(
        runSync(syncWith(failing)),
        throwsA(isA<NetworkFailure>()),
      );

      expect(remote.pageOffsets, isEmpty);
      expect((await metadataOf('reference')).status, 'failed');
    });
  });

  group('progreso (PA-01)', () {
    test('la BD emite un cambio por lote confirmado', () async {
      final counts = <int>[];
      final subscription = db.catalogDao.watchPokemonCount().listen(counts.add);
      await pumpEventQueue();

      await runSync(syncWith(FakePokemonRemote()));
      await pumpEventQueue();
      await subscription.cancel();

      expect(counts, [0, 200, 400, 450]);
    });
  });

  group('interrupción y reanudación (PA-09)', () {
    test('conserva los lotes confirmados y reanuda desde el cursor', () async {
      final remote = FakePokemonRemote()..failAtOffset = 400;

      await expectLater(
        runSync(syncWith(remote)),
        throwsA(isA<NetworkFailure>()),
      );

      expect(await db.catalogDao.countPokemon(), 400);
      final interrupted = await metadataOf('catalog');
      expect(interrupted.status, SyncMetadataStatus.failed);
      expect(interrupted.cursorOffset, 400);
      expect(interrupted.attempts, 1);
      expect(remote.pageOffsets, [0, 200, 400]);

      // Reinicio: coordinador y sync nuevos sobre la misma BD.
      final restarted = SyncCoordinator(
        metadata: db.syncMetadataDao,
        backoff: BackoffPolicy(jitter: 0),
      );
      addTearDown(restarted.dispose);
      remote
        ..failAtOffset = null
        ..pageOffsets.clear();
      await runSync(syncWith(remote, using: restarted), using: restarted);

      expect(remote.pageOffsets, [400], reason: 'solo pide lo que falta');
      expect(remote.referenceCalls, 1, reason: 'la referencia sigue vigente');
      expect(await db.catalogDao.countPokemon(), 450);
      final done = await metadataOf('catalog');
      expect(done.status, SyncMetadataStatus.completed);
      expect(done.cursorOffset, 0);
    });

    test(
      'el resultado de interrumpir y reanudar es el de una pasada limpia',
      () async {
        final interrupted = FakePokemonRemote()..failAtOffset = 200;
        await expectLater(
          runSync(syncWith(interrupted)),
          throwsA(isA<NetworkFailure>()),
        );
        interrupted.failAtOffset = null;
        await runSync(syncWith(interrupted));
        final afterResume = await catalogCounts(db);

        final clean = createTestDatabase();
        addTearDown(clean.close);
        final cleanCoordinator = SyncCoordinator(
          metadata: clean.syncMetadataDao,
          backoff: BackoffPolicy(jitter: 0),
        );
        addTearDown(cleanCoordinator.dispose);
        await time.run(
          () => cleanCoordinator.run<void>(
            CatalogSync.resourceKey,
            CatalogSync(
              remote: FakePokemonRemote(),
              local: CatalogLocalSource(clean),
              coordinator: cleanCoordinator,
            ).execute,
          ),
        );

        expect(afterResume, await catalogCounts(clean));
      },
    );
  });

  group('un lote es atómico', () {
    test(
      'un Pokémon inválido descarta todo el lote y no mueve el cursor',
      () async {
        final remote = FakePokemonRemote()..tamper = _removeName(250);

        await expectLater(
          runSync(syncWith(remote)),
          throwsA(isA<ValidationFailure>()),
        );

        expect(await db.catalogDao.countPokemon(), 200);
        expect(await db.catalogDao.getPokemon(201), isNull);
        expect((await metadataOf('catalog')).cursorOffset, 200);
      },
    );

    test('una FK rota deshace el lote entero en la BD', () async {
      final remote = FakePokemonRemote()..tamper = _breakTypeFk(250);

      await expectLater(runSync(syncWith(remote)), throwsA(anything));

      expect(await db.catalogDao.countPokemon(), 200);
      expect(await db.catalogDao.getPokemon(201), isNull);
      final counts = await catalogCounts(db);
      expect(counts['species'], 200, reason: 'tampoco quedan especies');
      expect((await metadataOf('catalog')).cursorOffset, 200);
    });
  });

  group('single-flight', () {
    test('dos solicitudes simultáneas hacen una sola pasada', () async {
      final remote = FakePokemonRemote();
      final sync = syncWith(remote);

      await time.run(
        () => Future.wait([
          coordinator.run<void>(CatalogSync.resourceKey, sync.execute),
          coordinator.run<void>(CatalogSync.resourceKey, sync.execute),
        ]),
      );

      expect(remote.pageOffsets, [0, 200, 400]);
      expect(remote.referenceCalls, 1);
    });
  });

  group('con el cliente HTTP y el presupuesto de llamadas', () {
    late PokeApiClient client;
    late ApiBudget budget;
    late List<String> operations;

    /// Sirve datos sintéticos según la operación y registra las llamadas.
    Future<http.Response> serve(http.Request request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final query = body['query'] as String;
      final variables = (body['variables'] ?? {}) as Map<String, dynamic>;
      final Map<String, dynamic> data;
      if (query.contains('query GetReferenceData')) {
        operations.add('GetReferenceData');
        data = syntheticReference();
      } else {
        operations.add('GetPokemonPage:${variables['offset']}');
        data = syntheticPage(
          offset: variables['offset'] as int,
          limit: variables['limit'] as int,
          total: 450,
        );
      }
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    CatalogSync httpSync() => CatalogSync(
      remote: PokemonRemoteSource(client: client, budget: budget),
      local: CatalogLocalSource(db),
      coordinator: coordinator,
    );

    setUp(() {
      operations = [];
      budget = ApiBudget(log: db.apiCallLogDao, limit: 3);
      client = PokeApiClient(
        endpoint: Uri.parse('https://example.test/graphql'),
        loader: OperationLoader(),
        httpClient: MockClient(serve),
      );
    });
    tearDown(() => client.dispose());

    test('pide variables correctas y registra cada llamada', () async {
      budget = ApiBudget(log: db.apiCallLogDao);

      await runSync(httpSync());

      expect(operations, [
        'GetReferenceData',
        'GetPokemonPage:0',
        'GetPokemonPage:200',
        'GetPokemonPage:400',
      ]);
      expect(await db.catalogDao.countPokemon(), 450);
      final log = await time.run(() => budget.used());
      expect(log, 4);
    });

    test(
      'al agotarse el presupuesto conserva el cursor y reanuda luego',
      () async {
        await expectLater(
          runSync(httpSync()),
          throwsA(isA<BudgetExhaustedFailure>()),
        );

        expect(operations, [
          'GetReferenceData',
          'GetPokemonPage:0',
          'GetPokemonPage:200',
        ]);
        expect(await db.catalogDao.countPokemon(), 400);
        final stopped = await metadataOf('catalog');
        expect(stopped.cursorOffset, 400);
        expect(stopped.nextRetryAt, isNotNull);

        time.advance(const Duration(minutes: 61));
        operations.clear();
        await runSync(httpSync());

        expect(operations, ['GetPokemonPage:400']);
        expect(await db.catalogDao.countPokemon(), 450);
      },
    );
  });
}

/// Remoto cuya referencia falla; las páginas delegan en [_inner].
class _FailingReference implements PokemonRemoteSource {
  _FailingReference(this._inner);

  final PokemonRemoteSource _inner;

  @override
  Future<Map<String, dynamic>> fetchReference() async =>
      throw const NetworkFailure();

  @override
  Future<Map<String, dynamic>> fetchPage({
    required int offset,
    required int limit,
  }) => _inner.fetchPage(offset: offset, limit: limit);
}
