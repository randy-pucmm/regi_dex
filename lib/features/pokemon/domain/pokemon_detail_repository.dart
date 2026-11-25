import 'evolution_chain.dart';
import 'pokemon_detail.dart';
import 'pokemon_move.dart';
import 'type_chart.dart';

abstract interface class PokemonDetailRepository {
  /// Detalle de [id] desde la base local; emite null si no está en el catálogo.
  Stream<PokemonDetail?> watchDetail(int id);

  /// Descarga el detalle de [id] y lo guarda. No hace nada si ya se descargó
  /// hace poco. Si falla lanza el `Failure` correspondiente y lo local queda
  /// como estaba.
  Future<void> refreshDetail(int id);

  /// Los juegos en los que [pokemonId] aprende movimientos y el que se
  /// muestra por defecto (el más reciente con movimientos por nivel).
  Future<MoveGames> moveGames(int pokemonId);

  /// La página [page] (desde 0) de los movimientos de [pokemonId] aprendidos
  /// por [method] en el juego [versionGroupId].
  Future<MovePage> moves(
    int pokemonId,
    MoveMethod method, {
    required int versionGroupId,
    required int page,
  });

  /// Eficacia entre tipos desde la referencia local; vacía mientras no se
  /// haya descargado.
  Stream<TypeChart> watchTypeChart();

  /// Cadena evolutiva de [pokemonId]. Emite null mientras no se conozcan las
  /// condiciones de evolución (hace falta descargar el detalle).
  Stream<EvolutionChain?> watchEvolutions(int pokemonId);
}
