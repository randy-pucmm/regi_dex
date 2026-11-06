import 'package:flutter_test/flutter_test.dart';
import 'package:graphql/client.dart';
import 'package:regi_dex/core/network/graphql_operation.dart';
import 'package:regi_dex/core/network/operation_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loader = OperationLoader();

  for (final operation in GraphqlOperation.values) {
    test('${operation.operationName} se carga y es GraphQL válido', () async {
      final text = await loader.load(operation);

      expect(text, contains('query ${operation.operationName}'));
      expect(() => gql(text), returnsNormally);
    });
  }

  test(
    'solo las operaciones que usan PokemonLight incluyen el fragmento',
    () async {
      for (final operation in GraphqlOperation.values) {
        final text = await loader.load(operation);
        expect(
          text.contains('fragment PokemonLight on pokemon'),
          operation.usesPokemonLight,
          reason: operation.operationName,
        );
      }
    },
  );

  test('el documento se guarda en memoria', () async {
    final first = await loader.load(GraphqlOperation.healthCheck);
    final second = await loader.load(GraphqlOperation.healthCheck);

    expect(identical(first, second), isTrue);
  });
}
