/// Estadísticas de un Pokémon en Champions: las de nivel 50 con 0 SP y
/// naturaleza neutra (la API ya las entrega así). Sobre ellas se suman los SP.
class ChampionsStats {
  const ChampionsStats({
    required this.hp,
    required this.attack,
    required this.defense,
    required this.spAttack,
    required this.spDefense,
    required this.speed,
  });

  final int hp;
  final int attack;
  final int defense;
  final int spAttack;
  final int spDefense;
  final int speed;

  @override
  bool operator ==(Object other) =>
      other is ChampionsStats &&
      other.hp == hp &&
      other.attack == attack &&
      other.defense == defense &&
      other.spAttack == spAttack &&
      other.spDefense == spDefense &&
      other.speed == speed;

  @override
  int get hashCode =>
      Object.hash(hp, attack, defense, spAttack, spDefense, speed);
}

/// Pokémon del índice de Champions, candidato para un equipo (RF-TB-02).
class ChampionsPokemon {
  const ChampionsPokemon({
    required this.showdownId,
    required this.name,
    required this.showdownName,
    required this.types,
    required this.abilities,
    required this.stats,
    required this.spriteUrl,
    this.hiddenAbility,
    this.pokeapiPokemonId,
  });

  /// Identificador estable del servicio (`raichualola`); sirve en las rutas.
  final String showdownId;

  /// Nombre para mostrar (`Raichu`).
  final String name;

  /// Nombre en el texto de Showdown (`Raichu-Alola`).
  final String showdownName;

  /// Tipos en inglés, como los publica el servicio (`Dragon`, `Ground`).
  final List<String> types;

  /// Habilidades normales.
  final List<String> abilities;

  /// Habilidad oculta, si la tiene.
  final String? hiddenAbility;

  final ChampionsStats stats;

  /// Imagen del servicio, para cuando no hay equivalente en PokéAPI.
  final String spriteUrl;

  /// Id del Pokémon en PokéAPI, o null si no se pudo relacionar.
  final int? pokeapiPokemonId;

  /// Todas las habilidades que puede llevar: normales y oculta.
  List<String> get allAbilities => [...abilities, ?hiddenAbility];
}
