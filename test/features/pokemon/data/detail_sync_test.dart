import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/network/operation_loader.dart';
import 'package:regi_dex/core/network/poke_api_client.dart';
import 'package:regi_dex/core/sync/api_budget.dart';
import 'package:regi_dex/core/sync/backoff_policy.dart';
import 'package:regi_dex/core/sync/sync_coordinator.dart';
import 'package:regi_dex/features/pokemon/data/catalog_local_source.dart';
import 'package:regi_dex/features/pokemon/data/detail_sync.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_mapper.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_remote_source.dart';

import '../../../core/database/database_test_helpers.dart';
import '../../../core/sync/fake_time.dart';
import 'catalog_test_data.dart';
import 'fake_pokemon_remote.dart';

/// Apunta el primer movimiento del detalle a uno que no existe (rompe la FK).
void _breakMoveFk(Map<String, dynamic> detail) {
  final pokemon = (detail['pokemon'] as List<dynamic>).first;
  ((pokemon['pokemonmoves'] as List<dynamic>).first
          as Map<String, dynamic>)['move_id'] =
      999;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeTime time;
  late SyncCoordinator coordinator;
  late FakePokemonRemote remote;
  late DetailSync sync;

  setUp(() async {
    db = createTestDatabase();
    time = FakeTime();
    coordinator = SyncCoordinator(
      metadata: db.syncMetadataDao,
      backoff: BackoffPolicy(jitter: 0),
    );
    remote = FakePokemonRemote();
    await CatalogLocalSource(db)
        .saveReference(mapReferenceData(syntheticReference()));
    sync = DetailSync(
      remote: remote,
      local: CatalogLocalSource(db),
      coordinator: coordinator,
    );
  });
  tearDown(() async {
    coordinator.dispose();
    await db.close();
  });

  Future<DetailSyncResult> run(int id, {bool force = false}) =>
      time.run(() => sync.sync(id, force: force));

  Future<SyncMetadataRow> metadataOf(String key) async =>
      (await db.syncMetadataDao.getEntry(key))!;

  group('descarga', () {
    test('hace una sola llamada y guarda todo el detalle', () async {
      final result = await run(7);

      expect(result.fetched, isTrue);
      expect(remote.detailIds, [7]);
      final counts = await catalogCounts(db);
      expect(counts['pokemon'], 1);
      expect(counts['species'], 1);
      expect(counts['pokemon_type'], 1);
      expect(counts['pokemon_stat'], 6);
      expect(counts['pokemon_ability'], 1);
      expect(counts['pokemon_move'], 2);
      expect(counts['pokemon_form'], 2);
      expect(counts['evolution'], 2);
    });

    test('guarda sprites shiny, textos en español y la fecha', () async {
      await run(7);

      final pokemon = (await db.catalogDao.getPokemon(7))!;
      expect(pokemon.detailSyncedAt, time.now);
      expect(pokemon.spriteShinyUrl, 'https://img.test/s/7.png');
      expect(pokemon.artworkShinyUrl, 'https://img.test/as/7.png');
      final species = await (db.select(
        db.species,
      )..where((s) => s.id.equals(7))).getSingle();
      expect(species.nameEs, 'Especie 7');
      expect(species.genusEs, 'Pokémon 7');
      final ability = await (db.select(
        db.abilities,
      )..where((a) => a.id.equals(8))).getSingle();
      expect(ability.nameEs, 'Habilidad 8');
      expect(ability.shortEffect, 'Efecto 8');
    });

    test('la referencia posterior no borra los textos en español', () async {
      await run(7);

      await CatalogLocalSource(db)
          .saveReference(mapReferenceData(syntheticReference()));

      final ability = await (db.select(
        db.abilities,
      )..where((a) => a.id.equals(8))).getSingle();
      expect(ability.nameEs, 'Habilidad 8');
    });

    test('registra el recurso detail:{id} en sync_metadata', () async {
      await run(7);

      final entry = await metadataOf('detail:7');
      expect(entry.status, SyncMetadataStatus.completed);
      expect(entry.lastSuccessAt, time.now);
    });

    test('repetirlo con force no duplica filas', () async {
      await run(7);
      await run(7, force: true);

      final counts = await catalogCounts(db);
      expect(counts['pokemon_move'], 2);
      expect(counts['pokemon_form'], 2);
      expect(counts['evolution'], 2);
      expect(counts['pokemon_stat'], 6);
    });
  });

  group('vigencia de 3 días (PS-03)', () {
    test('un detalle vigente no vuelve a llamar', () async {
      await run(7);
      time.advance(const Duration(days: 2, hours: 23));

      final result = await run(7);

      expect(result.fetched, isFalse);
      expect(remote.detailIds, [7]);
    });

    test('un detalle vencido se descarga otra vez', () async {
      await run(7);
      time.advance(DetailSync.detailMaxAge);

      final result = await run(7);

      expect(result.fetched, isTrue);
      expect(remote.detailIds, [7, 7]);
      expect((await db.catalogDao.getPokemon(7))!.detailSyncedAt, time.now);
    });

    test('un Pokémon del catálogo sin detalle lo descarga', () async {
      await db.catalogDao.upsertSpecies(
        SpeciesCompanion.insert(
          id: const Value(7),
          name: 'species-7',
          generationId: 1,
        ),
      );
      await db.catalogDao.upsertPokemon(
        PokemonsCompanion.insert(
          id: const Value(7),
          speciesId: 7,
          name: 'pokemon-7',
          lightSyncedAt: time.now,
        ),
        types: const [],
        stats: const [],
        abilities: const [],
      );

      expect(await time.run(() => sync.isFresh(7)), isFalse);
      await run(7);
      expect(await time.run(() => sync.isFresh(7)), isTrue);
    });

    test('dos aperturas a la vez comparten una sola llamada', () async {
      final results = await Future.wait([run(7), run(7)]);

      expect(remote.detailIds, [7]);
      expect(results[0], same(results[1]));
    });

    test('cada Pokémon tiene su propia llamada', () async {
      await Future.wait([run(7), run(8)]);

      expect(remote.detailIds, unorderedEquals([7, 8]));
    });
  });

  group('comparación con lo local (ADR-006)', () {
    test('un Pokémon ausente cuenta como cambio', () async {
      expect((await run(7)).changed, isTrue);
    });

    test('si coincide con el remoto no hay cambio', () async {
      await run(7);

      expect((await run(7, force: true)).changed, isFalse);
    });

    test('si lo local fue alterado gana el remoto', () async {
      await run(7);
      await (db.update(db.pokemonTypes)..where((t) => t.pokemonId.equals(7)))
          .write(const PokemonTypesCompanion(typeId: Value(1)));
      await (db.update(db.pokemons)..where((p) => p.id.equals(7))).write(
        const PokemonsCompanion(name: Value('alterado')),
      );

      final result = await run(7, force: true);

      expect(result.changed, isTrue);
      expect((await db.catalogDao.typesOf(7)).single.typeId, 8);
      expect((await db.catalogDao.getPokemon(7))!.name, 'pokemon-7');
    });
  });

  group('todo o nada (PS-07)', () {
    test('una FK rota deshace el detalle entero', () async {
      remote.tamperDetail = _breakMoveFk;

      await expectLater(run(7), throwsA(anything));

      final counts = await catalogCounts(db);
      for (final table in const [
        'pokemon',
        'species',
        'pokemon_type',
        'pokemon_stat',
        'pokemon_ability',
        'pokemon_move',
        'pokemon_form',
        'evolution',
      ]) {
        expect(counts[table], 0, reason: table);
      }
      expect((await metadataOf('detail:7')).status, SyncMetadataStatus.failed);
    });

    test('un detalle inválido no escribe nada', () async {
      remote.tamperDetail = (detail) =>
          ((detail['pokemon'] as List<dynamic>).first as Map<String, dynamic>)
              .remove('pokemonmoves');

      await expectLater(run(7), throwsA(anything));

      expect((await catalogCounts(db))['pokemon'], 0);
    });

    test('si falla al refrescar conserva el detalle anterior', () async {
      await run(7);
      final syncedAt = time.now;
      time.advance(const Duration(days: 4));
      remote.failDetail = true;

      await expectLater(run(7), throwsA(anything));

      final pokemon = (await db.catalogDao.getPokemon(7))!;
      expect(pokemon.detailSyncedAt, syncedAt);
      expect((await catalogCounts(db))['pokemon_move'], 2);
      expect((await metadataOf('detail:7')).status, SyncMetadataStatus.failed);
    });
  });

  group('con el cliente HTTP y el presupuesto de llamadas', () {
    late PokeApiClient client;
    late ApiBudget budget;
    late List<Map<String, dynamic>> requests;
    late List<String> logs;

    Future<http.Response> serve(http.Request request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      final variables = body['variables'] as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'data': syntheticDetail(variables['id'] as int)}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    setUp(() {
      requests = [];
      logs = [];
      budget = ApiBudget(log: db.apiCallLogDao);
      client = PokeApiClient(
        endpoint: Uri.parse('https://example.test/graphql'),
        loader: OperationLoader(),
        httpClient: MockClient(serve),
        log: logs.add,
      );
      sync = DetailSync(
        remote: PokemonRemoteSource(client: client, budget: budget),
        local: CatalogLocalSource(db),
        coordinator: coordinator,
      );
    });
    tearDown(() => client.dispose());

    test('abrir un detalle es una llamada con id e idiomas', () async {
      await run(25);

      expect(requests, hasLength(1));
      expect(requests.single['query'], contains('query GetPokemonDetail'));
      expect(requests.single['variables'], {
        'id': 25,
        'langs': ['es', 'en'],
      });
      expect(await time.run(() => budget.used()), 1);
      expect((await catalogCounts(db))['pokemon'], 1);
    });

    test('la consulta queda visible en consola (PA-02)', () async {
      await run(25);

      final line = logs.singleWhere((l) => l.contains('GetPokemonDetail'));
      expect(line, contains('id: 25'));
    });
  });
}
