import 'package:regi_dex/features/pokemon/domain/pokemon.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_query.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_repository.dart';

/// Repositorio falso: no toca red ni base de datos, cuenta las llamadas y
/// puede fallar a pedido.
class FakePokemonRepository implements PokemonRepository {
  final queries = <PokemonQuery>[];
  var refreshes = 0;

  /// Ids pedidos con `syncDetail`, en orden.
  final detailRequests = <int>[];

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

  /// Búsquedas remotas pedidas, en orden.
  final remoteSearches = <String>[];

  /// Si no es null, `searchRemote()` lo lanza.
  Object? searchError;

  @override
  Future<int> searchRemote(String search) async {
    remoteSearches.add(search);
    final error = searchError;
    if (error != null) throw error;
    return 0;
  }

  @override
  Future<void> syncDetail(int pokemonId) async {
    detailRequests.add(pokemonId);
  }
}
