import 'pokemon_detail.dart';
import 'pokemon_move.dart';

abstract interface class PokemonDetailRepository {
  /// Detalle de [id] desde la base local; emite null si no está en el catálogo.
  Stream<PokemonDetail?> watchDetail(int id);

  /// Descarga el detalle de [id] y lo guarda. No hace nada si ya se descargó
  /// hace poco. Si falla lanza el `Failure` correspondiente y lo local queda
  /// como estaba.
  Future<void> refreshDetail(int id);

  /// La página [page] (desde 0) de los movimientos de [pokemonId] aprendidos
  /// por [method], del juego más reciente con datos.
  Future<MovePage> moves(int pokemonId, MoveMethod method, {required int page});
}
