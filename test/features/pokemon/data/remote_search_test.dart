import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/network/operation_loader.dart';
import 'package:regi_dex/core/network/poke_api_client.dart';
import 'package:regi_dex/core/sync/api_budget.dart';
import 'package:regi_dex/features/pokemon/data/catalog_local_source.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_mapper.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_remote_source.dart';
import 'package:regi_dex/features/pokemon/data/remote_search.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_query.dart';

import '../../../core/database/database_test_helpers.dart';
import 'catalog_test_data.dart';
import 'fake_pokemon_remote.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakePokemonRemote remote;
  late RemoteSearch search;

  setUp(() async {
    db = createTestDatabase();
    await CatalogLocalSource(db)
        .saveReference(mapReferenceData(syntheticReference()));
    remote = FakePokemonRemote();
    search = RemoteSearch(remote: remote, local: CatalogLocalSource(db));
  });
  tearDown(() => db.close());

  group('RemoteSearch', () {
    test('busca por nombre y guarda lo encontrado', () async {
      remote.searchResultIds = [25, 26];

      final saved = await search.run(const SearchName('pika'));

      expect(saved, 2);
      expect(remote.searches, ['nombre:pika']);
      final ids = [
        for (final item in await db.catalogDao.watchPokemonWithTypes().first)
          item.pokemon.id,
      ];
      expect(ids, [25, 26]);
    });

    test('busca por número', () async {
      remote.searchResultIds = [377];

      await search.run(const SearchNumber(377));

      expect(remote.searches, ['numero:377']);
      expect(await db.catalogDao.getPokemon(377), isNotNull);
    });

    test('guarda también especie, tipos, stats y habilidades', () async {
      remote.searchResultIds = [25];

      await search.run(const SearchName('pika'));

      final counts = await catalogCounts(db);
      expect(counts['species'], 1);
      expect(counts['pokemon_type'], 1);
      expect(counts['pokemon_stat'], 6);
      expect(counts['pokemon_ability'], 1);
    });

    test('no toca el cursor ni crea filas de sync_metadata', () async {
      remote.searchResultIds = [25];

      await search.run(const SearchName('pika'));

      expect(await db.syncMetadataDao.watchAll().first, isEmpty);
    });

    test('sin resultados no guarda nada y devuelve 0', () async {
      final saved = await search.run(const SearchName('zzz'));

      expect(saved, 0);
      expect((await catalogCounts(db))['pokemon'], 0);
    });

    test('repetir una búsqueda no duplica filas', () async {
      remote.searchResultIds = [25];

      await search.run(const SearchName('pika'));
      await search.run(const SearchName('pika'));

      expect((await catalogCounts(db))['pokemon'], 1);
    });

    test('dos búsquedas iguales a la vez comparten una llamada', () async {
      remote.searchResultIds = [25];

      final results = await Future.wait([
        search.run(const SearchName('pika')),
        search.run(const SearchName('pika')),
      ]);

      expect(remote.searches, ['nombre:pika']);
      expect(results, [1, 1]);
    });

    test('términos distintos hacen llamadas distintas', () async {
      await Future.wait([
        search.run(const SearchName('pika')),
        search.run(const SearchNumber(25)),
      ]);

      expect(remote.searches, hasLength(2));
    });

    test('si falla propaga el Failure y no guarda nada', () async {
      remote.failSearch = true;

      await expectLater(
        search.run(const SearchName('pika')),
        throwsA(isA<NetworkFailure>()),
      );

      expect((await catalogCounts(db))['pokemon'], 0);
    });

    test('tras un fallo se puede volver a intentar', () async {
      remote.failSearch = true;
      await expectLater(
        search.run(const SearchName('pika')),
        throwsA(anything),
      );

      remote
        ..failSearch = false
        ..searchResultIds = [25];

      expect(await search.run(const SearchName('pika')), 1);
    });
  });

  group('con el cliente HTTP y el presupuesto', () {
    late PokeApiClient client;
    late List<Map<String, dynamic>> requests;

    setUp(() {
      requests = [];
      client = PokeApiClient(
        endpoint: Uri.parse('https://example.test/graphql'),
        loader: OperationLoader(),
        httpClient: MockClient((request) async {
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({
              'data': {
                'pokemon': [syntheticPokemon(25)],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        log: (_) {},
      );
      search = RemoteSearch(
        remote: PokemonRemoteSource(
          client: client,
          budget: ApiBudget(log: db.apiCallLogDao),
        ),
        local: CatalogLocalSource(db),
      );
    });
    tearDown(() => client.dispose());

    test('por nombre manda el patrón con comodines y id 0', () async {
      await search.run(const SearchName('pika'));

      expect(requests.single['query'], contains('query SearchPokemonRemote'));
      expect(requests.single['variables'], {
        'pattern': '%pika%',
        'id': 0,
        'limit': 20,
      });
      expect((await catalogCounts(db))['pokemon'], 1);
    });

    test('por número manda el id y un patrón vacío', () async {
      await search.run(const SearchNumber(377));

      expect(requests.single['variables'], {
        'pattern': '',
        'id': 377,
        'limit': 20,
      });
    });

    test('escapa los comodines del texto buscado', () async {
      await search.run(const SearchName(r'a_b%c\d'));

      expect(
        (requests.single['variables'] as Map<String, dynamic>)['pattern'],
        r'%a\_b\%c\\d%',
      );
    });

    test('gasta una llamada del presupuesto', () async {
      final budget = ApiBudget(log: db.apiCallLogDao);
      search = RemoteSearch(
        remote: PokemonRemoteSource(client: client, budget: budget),
        local: CatalogLocalSource(db),
      );

      await search.run(const SearchName('pika'));

      expect(await budget.used(), 1);
    });
  });
}
