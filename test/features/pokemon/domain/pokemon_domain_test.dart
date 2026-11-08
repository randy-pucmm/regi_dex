import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_query.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_repository.dart';
import 'package:regi_dex/features/pokemon/domain/refresh_catalog.dart';
import 'package:regi_dex/features/pokemon/domain/watch_pokemon.dart';

class _RecordingRepository implements PokemonRepository {
  final queries = <PokemonQuery>[];
  var refreshes = 0;

  @override
  Stream<List<Pokemon>> watchPokemon(PokemonQuery query) {
    queries.add(query);
    return Stream.value(const []);
  }

  @override
  Future<void> refresh() async => refreshes++;
}

Pokemon _bulbasaur({String name = 'bulbasaur', List<PokemonTypeRef>? types}) =>
    Pokemon(
      id: 1,
      name: name,
      baseStatTotal: 318,
      types:
          types ??
          const [
            PokemonTypeRef(id: 12, name: 'grass', nameEs: 'Planta'),
            PokemonTypeRef(id: 4, name: 'poison'),
          ],
    );

void main() {
  group('Pokemon', () {
    test('dos entidades con los mismos datos son iguales', () {
      expect(_bulbasaur(), _bulbasaur());
      expect(_bulbasaur().hashCode, _bulbasaur().hashCode);
    });

    test('cambia la igualdad si cambia el nombre o un tipo', () {
      expect(_bulbasaur(), isNot(_bulbasaur(name: 'ivysaur')));
      expect(
        _bulbasaur(),
        isNot(_bulbasaur(types: const [PokemonTypeRef(id: 12, name: 'grass')])),
      );
    });

    test('el orden de los tipos cuenta', () {
      final reversed = _bulbasaur(
        types: const [
          PokemonTypeRef(id: 4, name: 'poison'),
          PokemonTypeRef(id: 12, name: 'grass', nameEs: 'Planta'),
        ],
      );
      expect(_bulbasaur(), isNot(reversed));
    });
  });

  test('toda PokemonQuery vacía es igual a otra', () {
    expect(const PokemonQuery(), const PokemonQuery());
    expect(const PokemonQuery().hashCode, const PokemonQuery().hashCode);
  });

  group('casos de uso', () {
    test('WatchPokemon sin argumentos usa la consulta vacía', () async {
      final repository = _RecordingRepository();

      await WatchPokemon(repository)().first;

      expect(repository.queries, [const PokemonQuery()]);
    });

    test('RefreshCatalog delega en el repositorio', () async {
      final repository = _RecordingRepository();

      await RefreshCatalog(repository)();

      expect(repository.refreshes, 1);
    });
  });
}
