import 'package:regi_dex/features/pokemon/domain/pokemon.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_query.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_repository.dart';

/// Repositorio falso: no toca red ni base de datos, cuenta las llamadas y
/// puede fallar a pedido.
class FakePokemonRepository implements PokemonRepository {
  final queries = <PokemonQuery>[];
  var refreshes = 0;

  /// Si no es null, `refresh()` lo lanza.
  Object? refreshError;

  @override
  Stream<List<Pokemon>> watchPokemon(PokemonQuery query) {
    queries.add(query);
    return Stream.value(const []);
  }

  @override
  Future<void> refresh() async {
    refreshes++;
    final error = refreshError;
    if (error != null) throw error;
  }
}
