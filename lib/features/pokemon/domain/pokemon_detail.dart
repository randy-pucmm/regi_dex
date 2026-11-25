import 'pokemon.dart';

class PokemonAbilityRef {
  const PokemonAbilityRef({
    required this.name,
    required this.isHidden,
    this.nameEs,
    this.shortEffect,
  });

  final String name;
  final String? nameEs;
  final bool isHidden;
  final String? shortEffect;
}

/// Detalle de un Pokémon. [stats] y [abilities] quedan vacías hasta que se
/// descarga el detalle; [height] va en decímetros y [weight] en hectogramos.
class PokemonDetail {
  const PokemonDetail({
    required this.pokemon,
    required this.height,
    required this.weight,
    required this.stats,
    required this.abilities,
  });

  final Pokemon pokemon;
  final int height;
  final int weight;

  /// Estadísticas base por id de stat de PokéAPI (1 = PS … 6 = Velocidad).
  final Map<int, int> stats;
  final List<PokemonAbilityRef> abilities;
}
