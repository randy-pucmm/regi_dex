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

  static const maxEffectLength = 160;

  /// El efecto recortado en un espacio para que no pase de [maxEffectLength].
  String? get summary {
    final effect = shortEffect;
    if (effect == null || effect.length <= maxEffectLength) return effect;
    final cut = effect.substring(0, maxEffectLength);
    final space = cut.lastIndexOf(' ');
    return '${cut.substring(0, space < 0 ? maxEffectLength - 1 : space)}…';
  }
}

/// Variante de la especie (predeterminada, regional, Mega…).
class PokemonFormRef {
  // Las gorras de Pikachu llevan nombre de región pero no son formas regionales.
  static final _region = RegExp(r'(Alola|Galar|Hisui|Paldea)(?! Cap)');

  static final _costume = RegExp(
    r'(Cap|Cosplay|Rock Star|Belle|Pop Star|Phd|Libre)$',
  );

  const PokemonFormRef({required this.id, required this.label});

  /// Id de PokéAPI del Pokémon de esta forma.
  final int id;
  final String label;

  /// Región de la forma; null en las que no son regionales.
  String? get region => _region.firstMatch(label)?.group(0);

  /// Gorra o cosplay de Pikachu.
  bool get isCostume => _costume.hasMatch(label);
}

/// Imágenes de las especies cuyo aspecto cambia según el género.
typedef GenderArt = ({
  String? male,
  String? maleShiny,
  String female,
  String? femaleShiny,
});

/// Detalle de un Pokémon. [stats] y [abilities] quedan vacías hasta que se
/// descarga el detalle; [height] va en decímetros y [weight] en hectogramos.
class PokemonDetail {
  const PokemonDetail({
    required this.pokemon,
    required this.height,
    required this.weight,
    required this.stats,
    required this.abilities,
    this.speciesId,
    this.shinyUrl,
    this.eggGroups = const [],
    this.forms = const [],
    this.genderArt,
  });

  /// Lo que ya se sabe desde el catálogo mientras se lee la base.
  PokemonDetail.preview(this.pokemon)
    : height = 0,
      weight = 0,
      stats = const {},
      abilities = const [],
      speciesId = null,
      shinyUrl = null,
      eggGroups = const [],
      forms = const [],
      genderArt = null;

  final Pokemon pokemon;
  final int height;
  final int weight;

  /// Estadísticas base por id de stat de PokéAPI (1 = PS … 6 = Velocidad).
  final Map<int, int> stats;
  final List<PokemonAbilityRef> abilities;

  /// Número nacional: las formas tienen id propio pero comparten especie.
  final int? speciesId;
  final String? shinyUrl;
  final List<String> eggGroups;
  final List<PokemonFormRef> forms;
  final GenderArt? genderArt;
}
