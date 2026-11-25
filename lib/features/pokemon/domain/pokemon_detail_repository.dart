import 'pokemon_detail.dart';

abstract interface class PokemonDetailRepository {
  /// Detalle de [id] desde la base local; emite null si no está en el catálogo.
  Stream<PokemonDetail?> watchDetail(int id);
}
