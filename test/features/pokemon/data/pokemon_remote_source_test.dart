import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/network/operation_loader.dart';
import 'package:regi_dex/core/network/poke_api_client.dart';
import 'package:regi_dex/core/sync/api_budget.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_remote_source.dart';

import '../../../core/database/database_test_helpers.dart';
import 'catalog_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late PokeApiClient client;
  late ApiBudget budget;
  late List<String> logs;
  late PokemonRemoteSource remote;

  /// Crea el remoto con [respond] como servidor de PokéAPI.
  void serve(Map<String, dynamic> Function() respond) {
    client = PokeApiClient(
      endpoint: Uri.parse('https://example.test/graphql'),
      loader: OperationLoader(),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(respond()),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
      log: (_) {},
    );
    remote = PokemonRemoteSource(client: client, budget: budget, log: logs.add);
  }

  setUp(() {
    db = createTestDatabase();
    budget = ApiBudget(log: db.apiCallLogDao);
    logs = [];
  });
  tearDown(() async {
    client.dispose();
    await db.close();
  });

  group('respuestas parciales', () {
    test(
      'con datos y errores devuelve los datos y lo deja en consola',
      () async {
        serve(
          () => {
            'data': syntheticPage(offset: 0, limit: 5, total: 450),
            'errors': [
              {'message': 'campo no disponible'},
            ],
          },
        );

        final data = await remote.fetchPage(offset: 0, limit: 5);

        expect((data['pokemon'] as List), hasLength(5));
        expect(logs.single, contains('GetPokemonPage'));
        expect(logs.single, contains('datos parciales'));
        expect(logs.single, contains('campo no disponible'));
      },
    );

    test('la llamada parcial cuenta como una del presupuesto', () async {
      serve(
        () => {
          'data': syntheticPage(offset: 0, limit: 5, total: 450),
          'errors': [
            {'message': 'campo no disponible'},
          ],
        },
      );

      await remote.fetchPage(offset: 0, limit: 5);

      expect(await budget.used(), 1);
    });

    test('con errores y sin datos sigue siendo un fallo', () async {
      serve(
        () => {
          'errors': [
            {'message': 'boom'},
          ],
        },
      );

      await expectLater(
        remote.fetchPage(offset: 0, limit: 5),
        throwsA(isA<Exception>()),
      );
      expect(logs, isEmpty);
    });
  });
}
